import DeviceActivity
import Foundation

/// DeviceActivityMonitor extension.
/// The system calls intervalDidEnd when a named DeviceActivitySchedule interval completes.
/// We write a JSON event to the shared App Group container; the main app imports it into SwiftData.
final class WindowActivityMonitor: DeviceActivityMonitor {

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        appendEvent(ActivityEvent(
            appBundleID: "com.apple.deviceactivity",
            category: "General",
            durationSeconds: 0,
            timestamp: Date(),
            activityName: activity.rawValue
        ))
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Called when a usage threshold is reached for a monitored app/category
        appendEvent(ActivityEvent(
            appBundleID: "threshold.\(event.rawValue)",
            category: "SocialNetworking",
            durationSeconds: 0,
            timestamp: Date(),
            activityName: activity.rawValue
        ))
    }

    // MARK: - Shared Storage

    private func appendEvent(_ event: ActivityEvent) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.window.app"
        ) else { return }

        let file = groupURL.appendingPathComponent("activity_events.json")
        var existing: [ActivityEvent] = []

        if let data = try? Data(contentsOf: file) {
            existing = (try? JSONDecoder().decode([ActivityEvent].self, from: data)) ?? []
        }

        existing.append(event)

        if let data = try? JSONEncoder().encode(existing) {
            try? data.write(to: file, options: .atomic)
        }
    }
}

private struct ActivityEvent: Codable {
    let appBundleID: String
    let category: String
    let durationSeconds: Double
    let timestamp: Date
    let activityName: String
}
