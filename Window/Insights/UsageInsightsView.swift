import SwiftUI
import SwiftData

struct UsageInsightsView: View {
    @Query(sort: \UsageSnapshot.timestamp, order: .reverse) private var snapshots: [UsageSnapshot]
    @Query(sort: \RecommendationEvent.timestamp, order: .reverse) private var events: [RecommendationEvent]
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            List {
                // Productivity profile summary
                if let profile = profiles.first {
                    Section("Your Profile") {
                        ProfileSummaryRow(profile: profile)
                    }
                }

                // Today's screen time
                Section("Today's Screen Time") {
                    if todaySnapshots.isEmpty {
                        Text("No data yet.\nEnable Screen Time access in the app settings, or use the Debug Panel to inject sample data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(
                            groupedByCategory.sorted(by: { $0.value > $1.value }),
                            id: \.key
                        ) { category, seconds in
                            HStack {
                                Label(category, systemImage: categoryIcon(category))
                                Spacer()
                                Text(formatDuration(seconds))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                // Recommendation stats
                Section("This Week") {
                    let total = weekEvents.count
                    let accepted = weekEvents.filter { $0.outcome == .accepted }.count
                    let skipped = weekEvents.filter { $0.outcome == .skipped }.count
                    let breaks = weekEvents.filter { $0.outcome == .breakTaken }.count

                    if total == 0 {
                        Text("No recommendations logged yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        StatRow(label: "Recommendations", value: "\(total)")
                        StatRow(label: "Accepted", value: "\(accepted) (\(pct(accepted, of: total))%)")
                        StatRow(label: "Skipped", value: "\(skipped)")
                        StatRow(label: "Breaks taken", value: "\(breaks)")
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }

    // MARK: - Computed

    private var todaySnapshots: [UsageSnapshot] {
        let start = Calendar.current.startOfDay(for: Date())
        return snapshots.filter { $0.timestamp >= start }
    }

    private var weekEvents: [RecommendationEvent] {
        let cutoff = Date().addingTimeInterval(-604800)
        return events.filter { $0.timestamp >= cutoff }
    }

    private var groupedByCategory: [String: Double] {
        Dictionary(grouping: todaySnapshots, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.durationSeconds } }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func pct(_ value: Int, of total: Int) -> Int {
        total == 0 ? 0 : Int(Double(value) / Double(total) * 100)
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "SocialNetworking": return "person.2.fill"
        case "Entertainment": return "play.rectangle.fill"
        case "Games": return "gamecontroller.fill"
        case "Education": return "book.fill"
        case "Productivity": return "checkmark.square.fill"
        default: return "app.fill"
        }
    }
}

struct ProfileSummaryRow: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.chronotype.displayName)
                    .font(.subheadline).bold()
                Text("Focus: \(profile.focusDuration)min blocks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                EnergyBadge(label: "AM", value: profile.morningEnergy)
                EnergyBadge(label: "PM", value: profile.eveningEnergy)
            }
        }
    }
}

struct EnergyBadge: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(value * 100))%")
                .font(.caption).bold()
                .foregroundStyle(value > 0.6 ? .green : value > 0.4 ? .yellow : .orange)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
