import SwiftData
import Foundation

enum Chronotype: String, Codable, CaseIterable {
    case morning = "morning"
    case evening = "evening"
    case flexible = "flexible"

    var displayName: String {
        switch self {
        case .morning: return "Morning person"
        case .evening: return "Night owl"
        case .flexible: return "Depends on the day"
        }
    }
}

@Model
final class UserProfile {
    // Goal data (from GPT-4o onboarding conversation)
    var dreamLife: String = ""
    var tenYearGoal: String = ""
    var weeklyFocus: String = ""
    var keyHabitsData: Data = Data()  // [String] encoded as JSON

    // Productivity profile (from questionnaire)
    var chronotypeRaw: String = Chronotype.flexible.rawValue
    var focusDuration: Int = 45          // minutes before break
    var procrastinationTendency: Double = 0.5  // 0 = early bird, 1 = last-minute

    // Adaptive energy weights (updated by learning loop)
    var morningEnergy: Double = 0.6      // 0.0–1.0
    var eveningEnergy: Double = 0.6      // 0.0–1.0
    var taskSwitchTolerance: Double = 0.5

    var onboardingComplete: Bool = false
    var createdAt: Date = Date()
    var lastWeeklyReflection: Date?

    init() {}

    var chronotype: Chronotype {
        get { Chronotype(rawValue: chronotypeRaw) ?? .flexible }
        set { chronotypeRaw = newValue.rawValue }
    }

    var keyHabits: [String] {
        get { (try? JSONDecoder().decode([String].self, from: keyHabitsData)) ?? [] }
        set { keyHabitsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
