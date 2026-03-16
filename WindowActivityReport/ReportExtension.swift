import DeviceActivity
import SwiftUI

// MARK: - Processed data (Sendable so it can cross the makeConfiguration boundary)

struct ProcessedDay: Codable, Sendable {
    let dateString: String
    let date: Date
    var totalMinutes: Double
    var categoryMinutes: [String: Double]

    var distractingMinutes: Double {
        ["Social Networking", "Entertainment", "Games"]
            .reduce(0) { $0 + (categoryMinutes[$1] ?? 0) }
    }
}

// MARK: - Extension entry point

@main
struct WindowActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        WindowTotalActivityReport { days in
            ReportView(days: days)
        }
    }
}

// MARK: - Scene

private struct WindowTotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TotalActivity")
    let content: ([ProcessedDay]) -> ReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> [ProcessedDay] {
        var loaded: [ProcessedDay] = []
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for await activityData in data {
            var totalMins: Double = 0
            var catMins: [String: Double] = [:]
            var dayStart: Date?

            for await segment in activityData.activitySegments {
                if dayStart == nil {
                    let comps = calendar.dateComponents([.year, .month, .day], from: segment.dateInterval.start)
                    dayStart = calendar.date(from: comps)
                }
                totalMins += segment.totalActivityDuration / 60
                for await catActivity in segment.categories {
                    let name = catActivity.category.localizedDisplayName ?? "Other"
                    catMins[name, default: 0] += catActivity.totalActivityDuration / 60
                }
            }

            if totalMins > 0, let dayStart {
                loaded.append(ProcessedDay(
                    dateString: formatter.string(from: dayStart),
                    date: dayStart,
                    totalMinutes: totalMins,
                    categoryMinutes: catMins
                ))
            }
        }

        loaded.sort { $0.date < $1.date }
        persistToAppGroup(loaded)
        return loaded
    }

    private func persistToAppGroup(_ days: [ProcessedDay]) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.henryzhao.window"
        ) else { return }

        struct Report: Codable {
            var days: [ProcessedDay]
            var lastUpdated: Date
        }

        let file = groupURL.appendingPathComponent("usage_report.json")
        let report = Report(days: days, lastUpdated: Date())
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: file, options: .atomic)
        }
    }
}
