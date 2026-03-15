import SwiftData
import Foundation

@Model
final class UsageSnapshot {
    var timestamp: Date = Date()
    var appBundleID: String = ""
    var category: String = ""         // e.g. "SocialNetworking", "Entertainment"
    var durationSeconds: Double = 0

    init(appBundleID: String, category: String, durationSeconds: Double, timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.appBundleID = appBundleID
        self.category = category
        self.durationSeconds = durationSeconds
    }
}
