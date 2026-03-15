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

    static let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    private let scorer = ProductivityScorer()
    private let ranker = TaskRanker()
    private let openAI = OpenAIService.shared

    // MARK: - Public API

    func refreshIfNeeded(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot]) async {
        let report = UsageReport.loadFromAppGroup()
        let cacheStale = cachedAt.map { Date().timeIntervalSince($0) > Self.cacheTTL } ?? true
        if cacheStale {
            await refresh(profile: profile, tasks: tasks, snapshots: snapshots, report: report)
        } else {
            productivityScore = scorer.score(profile: profile, recentSnapshots: snapshots, report: report)
            currentTask = ranker.topTask(from: tasks, productivityScore: productivityScore)
        }
    }

    func refresh(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot]) async {
        let report = UsageReport.loadFromAppGroup()
        await refresh(profile: profile, tasks: tasks, snapshots: snapshots, report: report)
    }

    var cacheAgeDescription: String? {
        guard let cachedAt else { return nil }
        let minutes = Int(Date().timeIntervalSince(cachedAt) / 60)
        if minutes < 1 { return "just now" }
        return "\(minutes)m ago"
    }

    // MARK: - Private

    private func refresh(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot], report: UsageReport) async {
        isLoading = true
        errorMessage = nil

        let score = scorer.score(profile: profile, recentSnapshots: snapshots, report: report)
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
                messages: buildMessages(profile: profile, task: topTask, score: score, snapshots: snapshots, report: report),
                model: .mini,
                maxTokens: 100
            )
            cachedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
            let level = scorer.description(for: score)
            currentRecommendation = "Your energy is \(level) right now. Focus on: \(topTask.name) (\(topTask.estimatedMinutes) min)."
        }

        isLoading = false
    }

    private func buildMessages(
        profile: UserProfile,
        task: WindowTask,
        score: Double,
        snapshots: [UsageSnapshot],
        report: UsageReport
    ) -> [OpenAIMessage] {
        let system = "You are Window, an AI coach for students. Write 2 sentences: one connecting the task to the user's 10-year goal, one motivating them to start now. Be direct, specific, no fluff."

        let daysLeft = max(0, Int(task.deadline.timeIntervalSinceNow / 86400))
        let level = scorer.description(for: score)
        let cutoff = Date().addingTimeInterval(-7200)

        // Phone context: prefer real report data, fall back to threshold events
        let phoneContext: String
        if report.hasSufficientData {
            let cal = Calendar.current
            let todayDistracting = report.days
                .first { cal.isDate($0.date, inSameDayAs: Date()) }?
                .distractingMinutes ?? 0
            let avgDistracting = report.days.reduce(0.0) { $0 + $1.distractingMinutes } / Double(report.days.count)

            if todayDistracting == 0 {
                phoneContext = "Phone barely used today — possible focused period"
            } else if todayDistracting > avgDistracting * 1.5 {
                phoneContext = "Heavy distraction today: \(Int(todayDistracting))min vs \(Int(avgDistracting))min avg"
            } else {
                phoneContext = "Normal phone use today (\(Int(todayDistracting))min distracting)"
            }
        } else {
            let hasRecent = !snapshots.filter { $0.timestamp > cutoff }.isEmpty
            let socialMins = Int(
                snapshots
                    .filter { $0.timestamp > cutoff && $0.category == "SocialNetworking" }
                    .reduce(0.0) { $0 + $1.durationSeconds } / 60
            )
            phoneContext = !hasRecent
                ? "Phone idle — possible productive gap"
                : socialMins > 15 ? "Recent distraction: \(socialMins)min social media" : "Light phone use"
        }

        let lines = [
            "Energy: \(level)",
            "Goal: \(profile.tenYearGoal.isEmpty ? "not set" : profile.tenYearGoal)",
            "Task: \(task.name) (\(task.estimatedMinutes)min, due in \(daysLeft)d)",
            phoneContext
        ]

        return [
            .init(role: "system", content: system),
            .init(role: "user", content: lines.joined(separator: "\n"))
        ]
    }
}
