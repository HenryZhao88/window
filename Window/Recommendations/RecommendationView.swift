import SwiftUI
import SwiftData
import Observation

struct RecommendationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var tasks: [WindowTask]
    @Query(sort: \UsageSnapshot.timestamp, order: .reverse) private var snapshots: [UsageSnapshot]

    @State private var engine = RecommendationEngine()
    @State private var session = FocusSessionManager()
    @State private var lastOutcome: RecommendationOutcome?
    @State private var showOutcomeBanner = false

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
                                ErrorCard(message: error) { forceRefresh(profile: profile) }
                            } else if !engine.currentRecommendation.isEmpty {
                                RecommendationCard(
                                    text: engine.currentRecommendation,
                                    task: engine.currentTask,
                                    onStart: {
                                        if let task = engine.currentTask {
                                            session.start(task: task)
                                            logEvent(.accepted, profile: profile)
                                        }
                                    },
                                    onSkip: { logEvent(.skipped, profile: profile) },
                                    onBreak: { logEvent(.breakTaken, profile: profile) }
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
                        if let profile = profiles.first { forceRefresh(profile: profile) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(engine.isLoading)
                }
                if let age = engine.cacheAgeDescription {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Updated \(age)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                // Pull in any events the DeviceActivity extension wrote while the app was closed
                ScreenTimeService.shared.importExtensionEvents(into: modelContext)
                if let profile = profiles.first { refreshIfNeeded(profile: profile) }
            }
            .overlay(alignment: .top) {
                if showOutcomeBanner, let outcome = lastOutcome {
                    OutcomeBanner(outcome: outcome)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showOutcomeBanner)
            .fullScreenCover(
                isPresented: Binding(
                    get: { session.isActive },
                    set: { isPresented in
                        if !isPresented {
                            session.end()
                        }
                    }
                )
            ) {
                if let profile = profiles.first {
                    FocusTimerView(
                        session: session,
                        onComplete: { elapsedSeconds in
                            completeSession(elapsedSeconds: elapsedSeconds, profile: profile)
                        },
                        onSkip: {
                            logEvent(.skipped, profile: profile)
                            refreshIfNeeded(profile: profile)
                        },
                        onBreakLogged: {
                            logEvent(.breakTaken, profile: profile)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Private

    private func refreshIfNeeded(profile: UserProfile) {
        Task {
            await engine.refreshIfNeeded(
                profile: profile,
                tasks: tasks,
                snapshots: Array(snapshots.prefix(100))
            )
        }
    }

    private func forceRefresh(profile: UserProfile) {
        Task {
            await engine.refresh(
                profile: profile,
                tasks: tasks,
                snapshots: Array(snapshots.prefix(100))
            )
        }
    }

    private func logEvent(_ outcome: RecommendationOutcome, profile: UserProfile) {
        showBanner(outcome)

        let event = RecommendationEvent(
            recommendedTaskName: engine.currentTask?.name ?? "—",
            recommendationText: engine.currentRecommendation,
            productivityScore: engine.productivityScore,
            timeOfDay: Double(Calendar.current.component(.hour, from: Date())) / 24.0
        )
        event.outcome = outcome
        modelContext.insert(event)
        ProfileAdapter().adapt(profile: profile, event: event)
    }

    private func completeSession(elapsedSeconds: Int, profile: UserProfile) {
        if let task = session.activeTask {
            task.actualMinutes = elapsedSeconds / 60
        }
        logEvent(.accepted, profile: profile)
        refreshIfNeeded(profile: profile)
    }

    private func showBanner(_ outcome: RecommendationOutcome) {
        lastOutcome = outcome
        withAnimation { showOutcomeBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showOutcomeBanner = false }
        }
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
    let onStart: () -> Void
    let onSkip: () -> Void
    let onBreak: () -> Void

    @State private var showSkipConfirmation = false

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
                ActionButton("Start", icon: "play.fill", color: .blue, action: onStart)
                ActionButton("Skip", icon: "forward.fill", color: .gray) {
                    showSkipConfirmation = true
                }
                ActionButton("Break", icon: "cup.and.saucer.fill", color: .green, action: onBreak)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8, y: 2)
        .confirmationDialog(
            "Do you really want to skip?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, skip this task", role: .destructive, action: onSkip)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Window will recommend your next best task instead.")
        }
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

struct OutcomeBanner: View {
    let outcome: RecommendationOutcome

    private var config: (icon: String, label: String, color: Color) {
        switch outcome {
        case .accepted:   return ("play.fill",           "Starting task",  .blue)
        case .skipped:    return ("forward.fill",         "Skipped",        .gray)
        case .breakTaken: return ("cup.and.saucer.fill",  "Enjoy your break", .green)
        }
    }

    var body: some View {
        Label(config.label, systemImage: config.icon)
            .font(.subheadline).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(config.color)
            .clipShape(Capsule())
            .shadow(radius: 4)
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

@Observable
@MainActor
final class FocusSessionManager {
    var activeTask: WindowTask?
    var startedAt: Date?

    var isActive: Bool {
        activeTask != nil
    }

    func start(task: WindowTask) {
        activeTask = task
        startedAt = Date()
    }

    func elapsedSeconds(now: Date = Date()) -> Int {
        guard let startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt)))
    }

    func end() {
        activeTask = nil
        startedAt = nil
    }
}

struct FocusTimerView: View {
    let session: FocusSessionManager
    let onComplete: (Int) -> Void
    let onSkip: () -> Void
    let onBreakLogged: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var taskName: String {
        session.activeTask?.name ?? "Focus Session"
    }

    private var estimatedMinutes: Int? {
        session.activeTask?.estimatedMinutes
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsedSeconds = session.elapsedSeconds(now: context.date)

            VStack(spacing: 24) {
                Spacer()

                Text(taskName)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                if let estimatedMinutes {
                    Text("\(estimatedMinutes) minute focus block")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(formattedTime(elapsedSeconds))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                VStack(spacing: 12) {
                    Button("Complete Session") {
                        onComplete(elapsedSeconds)
                        session.end()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Log Break") {
                        onBreakLogged()
                    }
                    .buttonStyle(.bordered)

                    Button("Skip Session", role: .destructive) {
                        onSkip()
                        session.end()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            .background(Color(.systemBackground))
        }
    }

    private func formattedTime(_ elapsedSeconds: Int) -> String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
