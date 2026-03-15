import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "window.daily.reminder"

    private init() {}

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[Notifications] Authorization failed: \(error.localizedDescription)")
        }
    }

    func scheduleDailyReminder(for profile: UserProfile) {
        let content = UNMutableNotificationContent()
        content.title = "Window"
        content.body = reminderBody(for: profile)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: reminderTime(for: profile),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        center.add(request) { error in
            if let error {
                print("[Notifications] Scheduling failed: \(error.localizedDescription)")
            }
        }
    }

    private func reminderTime(for profile: UserProfile) -> DateComponents {
        switch profile.chronotype {
        case .morning:
            DateComponents(hour: 9, minute: 0)
        case .evening:
            DateComponents(hour: 19, minute: 0)
        case .flexible:
            DateComponents(hour: 12, minute: 0)
        }
    }

    private func reminderBody(for profile: UserProfile) -> String {
        let focus = profile.weeklyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if focus.isEmpty {
            return "Your focus window is open. Put a block on the calendar and start."
        }
        return "Your focus window is open. Make progress on \(focus)."
    }
}
