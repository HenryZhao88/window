import Foundation

struct ProductivityScorer {

    // MARK: - Main entry point

    /// Returns a productivity score in [0.0, 1.0].
    /// Uses real Screen Time report data when ≥2 days are available;
    /// falls back to the Gaussian chronotype model otherwise.
    func score(
        profile: UserProfile,
        currentDate: Date = Date(),
        recentSnapshots: [UsageSnapshot],
        report: UsageReport = .empty
    ) -> Double {
        let hour = Double(Calendar.current.component(.hour, from: currentDate))
        let energy = energyAtHour(hour, profile: profile)

        let fatigue: Double
        if report.hasSufficientData {
            fatigue = realDataFatigue(report: report, recentSnapshots: recentSnapshots, relativeTo: currentDate)
        } else {
            fatigue = thresholdFatigue(from: recentSnapshots, relativeTo: currentDate)
        }

        let idleBoost = idlePhoneBoost(from: recentSnapshots, relativeTo: currentDate)
        return max(0, min(1, energy - fatigue + idleBoost))
    }

    /// True when the phone hasn't been used recently — a likely focused period.
    func isProductiveWindow(snapshots: [UsageSnapshot], lookback: TimeInterval = 30 * 60) -> Bool {
        let cutoff = Date().addingTimeInterval(-lookback)
        return snapshots.filter { $0.timestamp > cutoff }.isEmpty
    }

    func label(for score: Double) -> String {
        switch score {
        case 0.7...: return "High Focus"
        case 0.4..<0.7: return "Moderate"
        default: return "Low Energy"
        }
    }

    func description(for score: Double) -> String {
        switch score {
        case 0.7...: return "high"
        case 0.4..<0.7: return "moderate"
        default: return "low"
        }
    }

    // MARK: - Energy model (chronotype Gaussian, unchanged)

    /// Gaussian blend peaking at 9am (morning) and 8pm (evening).
    private func energyAtHour(_ hour: Double, profile: UserProfile) -> Double {
        let morningComponent = gaussian(hour, center: 9, width: 3) * profile.morningEnergy
        let eveningComponent = gaussian(hour, center: 20, width: 3) * profile.eveningEnergy
        let afternoonDip = 0.25 * gaussian(hour, center: 14, width: 2)
        return min(1, max(0, morningComponent + eveningComponent - afternoonDip))
    }

    // MARK: - Fatigue: real Screen Time data path

    /// Uses the report extension's historical data.
    /// Compares today's tracked distraction minutes against the user's personal baseline.
    private func realDataFatigue(report: UsageReport, recentSnapshots: [UsageSnapshot], relativeTo date: Date) -> Double {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: date)

        // Baseline: average daily distracting minutes over all report days
        let baseline = report.days.reduce(0.0) { $0 + $1.distractingMinutes } / Double(report.days.count)

        // Today's distracting usage: prefer today's report day if available,
        // fall back to threshold-event snapshots for the current day
        let todayReportDay = report.days.first { cal.isDate($0.date, inSameDayAs: date) }
        let todayDistracting: Double

        if let today = todayReportDay {
            todayDistracting = today.distractingMinutes
        } else {
            // Use threshold snapshots as a proxy for today (under-counts but better than nothing)
            todayDistracting = recentSnapshots
                .filter { $0.timestamp >= todayStart && isDistractingCategory($0.category) }
                .reduce(0.0) { $0 + $1.durationSeconds / 60 }
        }

        guard baseline > 0 else { return thresholdFatigue(from: recentSnapshots, relativeTo: date) }

        // Fatigue scales with how far over baseline the user is today.
        // At baseline → ~0.1 fatigue. At 2× baseline → ~0.35 fatigue. At 0 → no fatigue.
        let ratio = todayDistracting / baseline
        return min(0.4, ratio * 0.18)
    }

    // MARK: - Fatigue: threshold-events fallback (pre-data-collection)

    /// Old approach: penalty from social/entertainment/games in past 2h.
    /// Max penalty: 0.4 at 2h continuous. Used until 2 report days accumulate.
    private func thresholdFatigue(from snapshots: [UsageSnapshot], relativeTo date: Date) -> Double {
        let cutoff = date.addingTimeInterval(-7200)
        let distractingSeconds = snapshots
            .filter { $0.timestamp > cutoff && isDistractingCategory($0.category) }
            .reduce(0.0) { $0 + $1.durationSeconds }
        return min(0.4, distractingSeconds / 7200.0 * 0.4)
    }

    // MARK: - Idle boost

    /// +0.1 when no phone activity recorded in the past 30 min (focus signal).
    private func idlePhoneBoost(from snapshots: [UsageSnapshot], relativeTo date: Date) -> Double {
        let cutoff = date.addingTimeInterval(-1800)
        return snapshots.filter { $0.timestamp > cutoff }.isEmpty ? 0.1 : 0
    }

    // MARK: - Helpers

    private func gaussian(_ x: Double, center: Double, width: Double) -> Double {
        exp(-pow(x - center, 2) / (2 * pow(width, 2)))
    }

    private func isDistractingCategory(_ category: String) -> Bool {
        ["SocialNetworking", "Entertainment", "Games"].contains(category)
    }
}
