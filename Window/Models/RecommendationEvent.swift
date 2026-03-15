import SwiftData
import Foundation

enum RecommendationOutcome: String, Codable {
    case accepted    = "accepted"
    case skipped     = "skipped"
    case breakTaken  = "breakTaken"
}

@Model
final class RecommendationEvent {
    // Recorded at the time the recommendation was shown
    var timestamp: Date = Date()
    var recommendedTaskName: String = ""
    var recommendationText: String = ""
    var productivityScore: Double = 0     // score at generation time
    var timeOfDay: Double = 0             // 0.0–1.0 normalized hour (hour / 24)
    var outcomeRaw: String = RecommendationOutcome.skipped.rawValue

    init(
        recommendedTaskName: String,
        recommendationText: String,
        productivityScore: Double,
        timeOfDay: Double
    ) {
        self.timestamp = Date()
        self.recommendedTaskName = recommendedTaskName
        self.recommendationText = recommendationText
        self.productivityScore = productivityScore
        self.timeOfDay = timeOfDay
    }

    var outcome: RecommendationOutcome {
        get { RecommendationOutcome(rawValue: outcomeRaw) ?? .skipped }
        set { outcomeRaw = newValue.rawValue }
    }
}
