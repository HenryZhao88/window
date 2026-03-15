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

    private let scorer = ProductivityScorer()
    private let ranker = TaskRanker()
    private let openAI = OpenAIService.shared

    func refresh(profile: UserProfile, tasks: [WindowTask], snapshots: [UsageSnapshot]) async {
        isLoading = true
        errorMessage = nil

        let score = scorer.score(profile: profile, recentSnapshots: snapshots)
        productivityScore = score

        guard let topTask = ranker.topTask(from: tasks, productivityScore: score) else {
            currentRecommendation = "No tasks yet. Add something to work on!"
            currentTask = nil
            isLoading = false
            return
        }

        currentTask = topTask

        let promptMessages = buildMessages(profile: profile, task: topTask, score: score, snapshots: snapshots)

        do {
            currentRecommendation = try await openAI.chat(messages: promptMessages, maxTokens: 120)
        } catch {
            errorMessage = error.localizedDescription
            // Graceful fallback — no GPT-4o needed for a basic recommendation
            let level = scorer.description(for: score)
            currentRecommendation = "Your productivity is currently \(level). Recommended: \(topTask.name) (\(topTask.estimatedMinutes) min)."
        }

        isLoading = false
    }

    // MARK: - Prompt Construction

    private func buildMessages(
        profile: UserProfile,
        task: WindowTask,
        score: Double,
        snapshots: [UsageSnapshot]
    ) -> [OpenAIMessage] {
        let system = """
        You are Window, a personal AI productivity coach for students.
        Give a direct, warm 2-3 sentence recommendation grounded in the user's goals.
        Always connect the task to their dream life. Never use generic advice.
        Be specific and motivating. Do not use bullet points or headers.
        """

        let daysLeft = max(0, task.deadline.timeIntervalSinceNow / 86400)
        let level = scorer.description(for: score)

        let cutoff = Date().addingTimeInterval(-7200)
        let socialMinutes = Int(
            snapshots
                .filter { $0.timestamp > cutoff && $0.category == "SocialNetworking" }
                .reduce(0.0) { $0 + $1.durationSeconds } / 60
        )

        var context = """
        Productivity level: \(level) (score: \(String(format: "%.2f", score)))
        10-year goal: \(profile.tenYearGoal.isEmpty ? "not yet captured" : profile.tenYearGoal)
        Weekly focus: \(profile.weeklyFocus.isEmpty ? "not yet captured" : profile.weeklyFocus)
        Task to recommend: "\(task.name)" — \(task.estimatedMinutes) min, difficulty \(Int(task.difficulty * 10))/10, due in \(Int(daysLeft)) day(s).
        """

        if socialMinutes > 10 {
            context += "\nDistractions: \(socialMinutes) min on social media in the last 2 hours."
        }

        context += "\n\nWrite a 2-3 sentence recommendation for what to do right now."

        return [
            .init(role: "system", content: system),
            .init(role: "user", content: context)
        ]
    }
}
