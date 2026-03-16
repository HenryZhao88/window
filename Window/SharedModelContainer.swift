import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.henryzhao.window"

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            WindowTask.self,
            UsageSnapshot.self,
            RecommendationEvent.self
        ])

        // Use App Group container so the extension can share data
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let storeURL = groupURL.appendingPathComponent("window.store")
            let config = ModelConfiguration(url: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }

        // Fallback: default container (Simulator without App Group)
        return try! ModelContainer(for: schema)
    }
}
