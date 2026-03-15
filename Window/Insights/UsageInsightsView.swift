import DeviceActivity
import SwiftUI
import SwiftData

struct UsageInsightsView: View {
    @Query(sort: \UsageSnapshot.timestamp) private var snapshots: [UsageSnapshot]
    @Query(sort: \RecommendationEvent.timestamp, order: .reverse) private var events: [RecommendationEvent]
    @Query private var profiles: [UserProfile]

    // Report filter: past 14 days of daily data
    private var reportFilter: DeviceActivityFilter {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Real Apple Screen Time data via DeviceActivityReport extension
                    VStack(alignment: .leading, spacing: 0) {
                        DeviceActivityReport(.init("TotalActivity"), filter: reportFilter)
                            .frame(minHeight: 300)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                    // What's tracked explanation (option 3 — honest labeling)
                    dataSourceCard

                    // Weekly recommendation stats
                    weeklyStatsCard

                    // Profile summary
                    if let profile = profiles.first {
                        profileCard(profile: profile)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }

    // MARK: - Data source explanation card (option 3)

    private var dataSourceCard: some View {
        let report = UsageReport.loadFromAppGroup()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: report.hasSufficientData ? "brain.head.profile" : "clock.badge.questionmark")
                    .foregroundStyle(report.hasSufficientData ? .blue : .orange)
                Text(report.hasSufficientData ? "Algorithm using real data" : "Building your baseline")
                    .font(.subheadline).bold()
                    .foregroundStyle(report.hasSufficientData ? .blue : .orange)
            }

            if report.hasSufficientData {
                Text("Window has \(report.days.count) days of Screen Time data and is using your real usage patterns to score productivity — not just a generic formula.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Use your phone normally for 2 days. Once Window has enough Screen Time data, it will replace its generic scoring model with patterns learned from your actual usage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !report.days.isEmpty {
                    Text("\(report.days.count) of 2 days collected")
                        .font(.caption2).bold()
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weekly stats card

    private var weeklyStatsCard: some View {
        let total    = weekEvents.count
        let accepted = weekEvents.filter { $0.outcome == .accepted }.count
        let skipped  = weekEvents.filter { $0.outcome == .skipped }.count
        let breaks   = weekEvents.filter { $0.outcome == .breakTaken }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            if total == 0 {
                Text("No recommendations logged yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 0) {
                    statPill(value: "\(accepted)", label: "Started",      color: .blue)
                    statPill(value: "\(skipped)",  label: "Skipped",      color: .gray)
                    statPill(value: "\(breaks)",   label: "Breaks",       color: .green)
                    statPill(value: "\(pct(accepted, of: total))%", label: "Accept rate", color: .purple)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func profileCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Profile")
                .font(.headline)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.chronotype.displayName)
                        .font(.subheadline).bold()
                    Text("Focus blocks: \(profile.focusDuration)min")
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
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).bold().foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed

    private var weekEvents: [RecommendationEvent] {
        let cutoff = Date().addingTimeInterval(-604800)
        return events.filter { $0.timestamp >= cutoff }
    }

    private func pct(_ value: Int, of total: Int) -> Int {
        total == 0 ? 0 : Int(Double(value) / Double(total) * 100)
    }
}

// MARK: - Supporting views (kept here so existing code that references them compiles)

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
