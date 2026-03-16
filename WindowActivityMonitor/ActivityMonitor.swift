import DeviceActivity
import Foundation
import UserNotifications

// MARK: - DeviceActivity name constants (extension target)

extension DeviceActivityName {
    static let daily = Self("window.daily")
}

extension DeviceActivityEvent.Name {
    static let socialThreshold      = Self("window.social.20min")
    static let socialHeavyThreshold = Self("window.social.40min")
}

// MARK: - Monitor

final class WindowActivityMonitor: DeviceActivityMonitor {

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // End of the daily monitoring window — write an interval boundary event.
        // The main app uses these to detect "clean days" (no heavy threshold reached).
        appendEvent(ActivityEvent(
            appBundleID: "com.window.interval.end",
            category: "IntervalEnd",
            durationSeconds: 0,
            timestamp: Date(),
            activityName: activity.rawValue
        ))
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let isHeavy = event == .socialHeavyThreshold
        let durationSeconds: Double = isHeavy ? 40 * 60 : 20 * 60

        // Write distraction snapshot for the main app's scorer
        appendEvent(ActivityEvent(
            appBundleID: "threshold.\(event.rawValue)",
            category: "SocialNetworking",
            durationSeconds: durationSeconds,
            timestamp: Date(),
            activityName: activity.rawValue
        ))

        // Nudge the user to focus
        sendThresholdNotification(isHeavy: isHeavy)
    }

    // MARK: - Shared Storage

    private func appendEvent(_ event: ActivityEvent) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.henryzhao.window"
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

    // MARK: - Notifications

    private func sendThresholdNotification(isHeavy: Bool) {
        let content = UNMutableNotificationContent()

        if isHeavy {
            content.title = "Time to refocus"
            content.body = "You've been on distracting apps for 40+ minutes. Open Window — your next task is waiting."
        } else {
            content.title = "Productive window ahead"
            content.body = "You've hit your app limit. This is a great time to focus. Open Window to get started."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "threshold_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Shared event model (extension copy)

private struct ActivityEvent: Codable {
    let appBundleID: String
    let category: String
    let durationSeconds: Double
    let timestamp: Date
    let activityName: String
}
