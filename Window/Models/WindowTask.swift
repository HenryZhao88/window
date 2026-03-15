import SwiftData
import Foundation

// Named WindowTask to avoid conflict with Swift concurrency's Task type
@Model
final class WindowTask {
    var name: String = ""
    var difficulty: Double = 0.5          // 0.0–1.0
    var deadline: Date = Date()
    var estimatedMinutes: Int = 30
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var actualMinutes: Int? = nil         // recorded on completion for calibration
    var createdAt: Date = Date()

    init(name: String, difficulty: Double, deadline: Date, estimatedMinutes: Int) {
        self.name = name
        self.difficulty = difficulty
        self.deadline = deadline
        self.estimatedMinutes = estimatedMinutes
    }
}
