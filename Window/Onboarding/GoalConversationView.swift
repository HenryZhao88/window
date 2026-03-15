import SwiftUI
import SwiftData

// MARK: - Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" | "assistant"
    let content: String
}

private struct GoalSummary: Codable {
    let tenYearGoal: String
    let weeklyFocus: String
    let keyHabits: [String]
}

// MARK: - View

struct GoalConversationView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var messages: [ChatMessage] = []
    @State private var userInput = ""
    @State private var isLoading = false
    @State private var isExtracting = false
    @State private var conversationDone = false
    @State private var errorMessage: String?

    private let openAI = OpenAIService.shared
    private let maxUserTurns = 4  // number of user replies before wrapping up

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            chatArea
            inputBar
        }
        .onAppear { startConversation() }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 4) {
            Text("Let's dream a little")
                .font(.title2).bold()
            Text("Your answers shape every recommendation Window makes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        ChatBubble(message: msg).id(msg.id)
                    }
                    if isLoading { TypingIndicator() }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: isLoading) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        Divider()
        if conversationDone {
            Button {
                extractAndSave()
            } label: {
                Label(isExtracting ? "Saving your profile…" : "Continue", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isExtracting)
            .padding()
        } else {
            HStack(spacing: 10) {
                TextField("Type your answer…", text: $userInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4)
                    .disabled(isLoading)

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? .blue : .gray)
                }
                .disabled(!canSend)
            }
            .padding()
        }

        if let error = errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.bottom, 8)
        }
    }

    private var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Logic

    private func startConversation() {
        Task {
            isLoading = true
            do {
                let reply = try await openAI.chat(
                    messages: [
                        .init(role: "system", content: coachSystemPrompt),
                        .init(role: "user", content: "Begin. Ask your first question.")
                    ],
                    model: .mini,
                    maxTokens: 100
                )
                messages.append(.init(role: "assistant", content: reply))
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func sendMessage() {
        let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        userInput = ""
        messages.append(.init(role: "user", content: text))

        let userTurns = messages.filter { $0.role == "user" }.count

        Task {
            isLoading = true
            do {
                var apiMessages: [OpenAIMessage] = [.init(role: "system", content: coachSystemPrompt)]
                apiMessages += messages.map { .init(role: $0.role, content: $0.content) }

                if userTurns >= maxUserTurns {
                    apiMessages.append(.init(
                        role: "user",
                        content: "Wrap up the conversation with a warm 1-2 sentence closing. Don't ask another question."
                    ))
                }

                let reply = try await openAI.chat(messages: apiMessages, model: .mini, maxTokens: 120)
                messages.append(.init(role: "assistant", content: reply))

                if userTurns >= maxUserTurns {
                    conversationDone = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func extractAndSave() {
        isExtracting = true
        Task {
            let transcript = messages
                .map { "\($0.role == "user" ? "Student" : "Coach"): \($0.content)" }
                .joined(separator: "\n")

            let extractionPrompt = """
            Extract a JSON object from this coaching conversation. Use exactly these keys:
            - "tenYearGoal": a concise 1-2 sentence description of the student's 10-year vision
            - "weeklyFocus": the single most important thing they want to work on this week
            - "keyHabits": an array of 2-4 habits or behaviors they want to build

            Conversation:
            \(transcript)

            Return ONLY valid JSON. No markdown, no extra text.
            """

            do {
                // Use the smarter model only here — JSON accuracy matters for the user's profile
                let json = try await openAI.chat(
                    messages: [.init(role: "user", content: extractionPrompt)],
                    model: .full,
                    jsonMode: true,
                    maxTokens: 200
                )

                if let data = json.data(using: .utf8),
                   let summary = try? JSONDecoder().decode(GoalSummary.self, from: data) {
                    let profile: UserProfile
                    if let existing = profiles.first {
                        profile = existing
                    } else {
                        profile = UserProfile()
                        modelContext.insert(profile)
                    }
                    profile.dreamLife = transcript
                    profile.tenYearGoal = summary.tenYearGoal
                    profile.weeklyFocus = summary.weeklyFocus
                    profile.keyHabits = summary.keyHabits
                }
            } catch {
                // Even if extraction fails, allow the user to proceed
                print("[GoalConversation] Extraction failed: \(error)")
            }

            isExtracting = false
            onComplete()
        }
    }

    private var coachSystemPrompt: String {
        """
        You are a warm, perceptive life coach helping a student clarify their goals.
        Ask ONE question at a time. Explore their dream life, career aspirations, and what success means to them.
        Keep each message to 2-3 sentences max. Be direct and encouraging.
        Good starter questions: "Describe your dream life in 10 years — what does a typical Tuesday look like?",
        "What's standing between you and that life right now?",
        "What's one thing you want to make consistent progress on this week?"
        After \(maxUserTurns) student replies, wrap up warmly without asking another question.
        """
    }
}

// MARK: - Chat UI Components

struct ChatBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.secondary)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { animating = true }
    }
}
