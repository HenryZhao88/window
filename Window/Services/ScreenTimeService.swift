import DeviceActivity
import FamilyControls
import Foundation
import SwiftData

// MARK: - DeviceActivity name constants (main app target)

extension DeviceActivityName {
    static let daily = Self("window.daily")
}

extension DeviceActivityEvent.Name {
    static let socialThreshold      = Self("window.social.20min")
    static let socialHeavyThreshold = Self("window.social.40min")
}

// MARK: - Service

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()
    private init() {}

    @Published var isAuthorized = false

    private let activityCenter = DeviceActivityCenter()

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    private let selectionKey = "familyActivitySelection"

    // MARK: - Authorization

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

    // MARK: - Monitoring

    /// Start DeviceActivity monitoring with the user's app selection.
    /// Thresholds: 20 min (alert) and 40 min (heavy use alert).
    func startMonitoring(selection: FamilyActivitySelection) {
        persistSelection(selection)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        let hasTokens = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty

        if hasTokens {
            events[.socialThreshold] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: 20)
            )
            events[.socialHeavyThreshold] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: 40)
            )
        }

        do {
            try activityCenter.startMonitoring(
                DeviceActivityName.daily,
                during: schedule,
                events: events
            )
            print("[ScreenTime] Monitoring started")
        } catch {
            print("[ScreenTime] Failed to start monitoring: \(error)")
        }
    }

    /// Re-start monitoring on app launch using the persisted selection (if any).
    func resumeMonitoringIfNeeded() {
        guard let selection = savedSelection() else { return }
        startMonitoring(selection: selection)
    }

    // MARK: - Selection Persistence

    func persistSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        sharedDefaults?.set(data, forKey: selectionKey)
    }

    func savedSelection() -> FamilyActivitySelection? {
        guard let data = sharedDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return nil }
        return selection
    }

    // MARK: - Usage Report (written by DeviceActivityReport extension)

    /// Load the full Screen Time report the report extension persisted to the App Group.
    func loadUsageReport() -> UsageReport {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupIdentifier
        ) else { return .empty }

        let file = groupURL.appendingPathComponent("usage_report.json")
        guard let data = try? Data(contentsOf: file),
              let report = try? JSONDecoder().decode(UsageReport.self, from: data)
        else { return .empty }

        return report
    }

    // MARK: - Threshold Event Import

    /// Import events written by the DeviceActivity extension into SwiftData.
    /// Returns true if any events were imported (signals new snapshot data).
    ///
    /// Uses an atomic rename to avoid the race where the extension writes new events
    /// between our read and our clear. The extension always writes to activity_events.json;
    /// we rename it to activity_events_processing.json before reading, so the extension
    /// can immediately start a fresh file with no data loss.
    @discardableResult
    func importExtensionEvents(into context: ModelContext) -> Bool {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupIdentifier
        ) else { return false }

        let eventsFile = groupURL.appendingPathComponent("activity_events.json")
        let processingFile = groupURL.appendingPathComponent("activity_events_processing.json")
        let fm = FileManager.default

        // Process any file left over from a previous crash before we rename a new one.
        var didImport = false
        if fm.fileExists(atPath: processingFile.path) {
            didImport = processEventsFile(processingFile, into: context)
        }

        // Atomic rename: the extension can safely start writing to activity_events.json
        // again the moment this returns; no events will be lost or double-counted.
        do {
            try fm.moveItem(at: eventsFile, to: processingFile)
        } catch {
            return didImport
        }

        didImport = processEventsFile(processingFile, into: context) || didImport
        return didImport
    }

    private func processEventsFile(_ url: URL, into context: ModelContext) -> Bool {
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([ActivityEvent].self, from: data),
              !events.isEmpty
        else { return false }

        for event in events {
            context.insert(UsageSnapshot(
                appBundleID: event.appBundleID,
                category: event.category,
                durationSeconds: event.durationSeconds,
                timestamp: event.timestamp
            ))
        }
        return true
    }
}

// MARK: - Shared event model

struct ActivityEvent: Codable {
    let appBundleID: String
    let category: String
    let durationSeconds: Double
    let timestamp: Date
    let activityName: String
}
