import Foundation

/// One day of aggregated Screen Time data written by the DeviceActivityReport extension
/// into the App Group, then read by the main app for scoring.
struct UsageReportDay: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String          // "YYYY-MM-DD"
    let date: Date
    var totalMinutes: Double
    var categoryMinutes: [String: Double]   // display name → minutes, e.g. "Social Networking" → 45.0

    /// Minutes from distracting categories (social, entertainment, games).
    var distractingMinutes: Double {
        let distractingKeys = ["Social Networking", "Entertainment", "Games"]
        return distractingKeys.reduce(0) { $0 + (categoryMinutes[$1] ?? 0) }
    }
}

struct UsageReport: Codable {
    var days: [UsageReportDay]
    var lastUpdated: Date

    static let empty = UsageReport(days: [], lastUpdated: .distantPast)
    var hasSufficientData: Bool { days.count >= 2 }

    static func loadFromAppGroup() -> UsageReport {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupIdentifier
        ) else {
            return .empty
        }

        let fileURL = groupURL.appendingPathComponent("usage_report.json")
        guard let data = try? Data(contentsOf: fileURL),
              let report = try? JSONDecoder().decode(UsageReport.self, from: data) else {
            return .empty
        }

        return report
    }
}
