import Foundation
import Observation

@Observable
@MainActor
final class RecommendationEngine {
    var currentRecommendation = ""
    var currentTask: WindowTask?
    var productivityScore: Double = 0
    var isLoading = false
    var errorMessage: String?
    var cachedAt: Date?

    /// How long a cached recommendation stays valid before a new GPT call is made.
    static let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    private let scorer = ProductivityScorer()
    private let ranker = TaskRanker()
    private let openAI = OpenAIService.shared

    // MARK: - Public API

    /// Call on button taps or minor events — updates the score and task locally,
    /// but only calls GPT if the cache has expired.
    func refreshIfNeeded(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot]) async {
        let cacheStale = cachedAt.map { Date().timeIntervalSince($0) > Self.cacheTTL } ?? true
        if cacheStale {
            await refresh(profile: profile, tasks: tasks, snapshots: snapshots)
        } else {
            // Recompute score locally (free) but keep cached recommendation text
            productivityScore = scorer.score(profile: profile, recentSnapshots: snapshots)
            currentTask = ranker.topTask(from: tasks, productivityScore: productivityScore)
        }
    }

    /// Always makes a GPT call. Use for explicit pull-to-refresh only.
    func refresh(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot]) async {
        isLoading = true
        errorMessage = nil

        let score = scorer.score(profile: profile, recentSnapshots: snapshots)
        productivityScore = score

        guard let topTask = ranker.topTask(from: tasks, productivityScore: score) else {
            currentRecommendation = "No tasks yet — add one to get started!"
            currentTask = nil
            isLoading = false
            return
        }

        currentTask = topTask

        do {
            currentRecommendation = try await openAI.chat(
                messages: buildMessages(profile: profile, task: topTask, score: score, snapshots: snapshots),
                model: .mini,
                maxTokens: 100   // 2-3 sentences fits comfortably in 100 tokens
            )
            cachedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
            // Local fallback — no API cost
            let level = scorer.description(for: score)
            currentRecommendation = "Your energy is \(level) right now. Focus on: \(topTask.name) (\(topTask.estimatedMinutes) min)."
        }

        isLoading = false
    }

    var cacheAgeDescription: String? {
        guard let cachedAt else { return nil }
        let minutes = Int(Date().timeIntervalSince(cachedAt) / 60)
        if minutes < 1 { return "just now" }
        return "\(minutes)m ago"
    }

    // MARK: - Prompt Construction

    private func buildMessages(
        profile: UserProfile,
        task: WindowTask,
        score: Double,
        snapshots: [UsageSnapshot]
    ) -> [OpenAIMessage] {
        // Concise system prompt — fewer tokens = lower cost
        let system = "You are Window, an AI coach for students. Write 2 sentences: one connecting the task to the user's 10-year goal, one motivating them to start now. Be direct, specific, no fluff."

        let daysLeft = max(0, Int(task.deadline.timeIntervalSinceNow / 86400))
        let level = scorer.description(for: score)

        let cutoff = Date().addingTimeInterval(-7200)
        let socialMinutes = Int(
            snapshots
                .filter { $0.timestamp > cutoff && $0.category == "SocialNetworking" }
                .reduce(0.0) { $0 + $1.durationSeconds } / 60
        )

        // Compact context — only what GPT actually needs
        var lines = [
            "Energy: \(level)",
            "Goal: \(profile.tenYearGoal.isEmpty ? "not set" : profile.tenYearGoal)",
            "Task: \(task.name) (\(task.estimatedMinutes)min, due in \(daysLeft)d)"
        ]
        if socialMinutes > 15 {
            lines.append("Recent distraction: \(socialMinutes)min social media")
        }

        return [
            .init(role: "system", content: system),
            .init(role: "user", content: lines.joined(separator: "\n"))
        ]
    }
}
