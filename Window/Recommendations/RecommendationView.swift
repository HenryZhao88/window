import SwiftUI
import SwiftData

struct RecommendationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var tasks: [WindowTask]
    @Query(sort: \UsageSnapshot.timestamp, order: .reverse) private var snapshots: [UsageSnapshot]

    @State private var engine = RecommendationEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let profile = profiles.first {
                        ProductivityScoreCard(score: engine.productivityScore)

                        Group {
                            if engine.isLoading {
                                LoadingCard()
                            } else if let error = engine.errorMessage {
                                ErrorCard(message: error) { refresh(profile: profile) }
                            } else if !engine.currentRecommendation.isEmpty {
                                RecommendationCard(
                                    text: engine.currentRecommendation,
                                    task: engine.currentTask,
                                    onAction: { handleAction($0, profile: profile) }
                                )
                            }
                        }

                        if tasks.filter({ !$0.isCompleted }).isEmpty {
                            ContentUnavailableView(
                                "No tasks yet",
                                systemImage: "plus.circle",
                                description: Text("Add a task and Window will tell you what to focus on.")
                            )
                            .padding(.top, 20)
                        }

                        if !profile.tenYearGoal.isEmpty {
                            GoalBanner(goal: profile.tenYearGoal)
                        }
                    } else {
                        ContentUnavailableView("Complete onboarding to get started", systemImage: "sparkles")
                    }
                }
                .padding()
            }
            .navigationTitle("Window")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let profile = profiles.first { refresh(profile: profile) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(engine.isLoading)
                }
            }
            .onAppear {
                if let profile = profiles.first { refresh(profile: profile) }
            }
        }
    }

    private func refresh(profile: UserProfile) {
        Task {
            await engine.refresh(
                profile: profile,
                tasks: tasks,
                snapshots: Array(snapshots.prefix(200))
            )
        }
    }

    private func handleAction(_ outcome: RecommendationOutcome, profile: UserProfile) {
        guard let task = engine.currentTask else { return }

        let event = RecommendationEvent(
            recommendedTaskName: task.name,
            recommendationText: engine.currentRecommendation,
            productivityScore: engine.productivityScore,
            timeOfDay: Double(Calendar.current.component(.hour, from: Date())) / 24.0
        )
        event.outcome = outcome
        modelContext.insert(event)

        ProfileAdapter().adapt(profile: profile, event: event)
        refresh(profile: profile)
    }
}

// MARK: - Score Card

struct ProductivityScoreCard: View {
    let score: Double

    private var label: String {
        switch score {
        case 0.7...: return "High Focus"
        case 0.4..<0.7: return "Moderate"
        default: return "Low Energy"
        }
    }

    private var color: Color {
        switch score {
        case 0.7...: return .green
        case 0.4..<0.7: return .yellow
        default: return .orange
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Right now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.title2).bold()
                    .foregroundStyle(color)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: score)
                Text("\(Int(score * 100))")
                    .font(.caption).bold()
            }
            .frame(width: 52, height: 52)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let text: String
    let task: WindowTask?
    let onAction: (RecommendationOutcome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text)
                .font(.body)
                .lineSpacing(5)

            if let task {
                HStack {
                    Label(task.name, systemImage: "doc.text.fill")
                        .font(.subheadline).bold()
                        .lineLimit(1)
                    Spacer()
                    Text("\(task.estimatedMinutes)m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                ActionButton("Start", icon: "play.fill", color: .blue) { onAction(.accepted) }
                ActionButton("Skip", icon: "forward.fill", color: .gray) { onAction(.skipped) }
                ActionButton("Break", icon: "cup.and.saucer.fill", color: .green) { onAction(.breakTaken) }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    init(_ title: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.color = color; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Supporting Cards

struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Getting your recommendation…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct GoalBanner: View {
    let goal: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Your 10-year goal", systemImage: "star.fill")
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            Text(goal)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
