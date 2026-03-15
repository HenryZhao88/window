import FamilyControls
import Foundation
import SwiftData

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()
    private init() {}

    @Published var isAuthorized = false

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            isAuthorized = false
            print("[ScreenTime] Authorization failed: \(error.localizedDescription)")
        }
    }

    func checkStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // Read events written by the DeviceActivity extension from the App Group
    func importExtensionEvents(into context: ModelContext) {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupIdentifier
        ) else { return }

        let eventsFile = groupURL.appendingPathComponent("activity_events.json")
        guard let data = try? Data(contentsOf: eventsFile),
              let events = try? JSONDecoder().decode([ActivityEvent].self, from: data)
        else { return }

        for event in events {
            let snapshot = UsageSnapshot(
                appBundleID: event.appBundleID,
                category: event.category,
                durationSeconds: event.durationSeconds,
                timestamp: event.timestamp
            )
            context.insert(snapshot)
        }

        // Clear the file after import
        try? "[]".data(using: .utf8)?.write(to: eventsFile)
    }
}

struct ActivityEvent: Codable {
    let appBundleID: String
    let category: String
    let durationSeconds: Double
    let timestamp: Date
}
