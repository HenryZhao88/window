import Foundation

struct ProductivityScorer {

    /// Returns a productivity score in [0.0, 1.0]
    func score(
        profile: UserProfile,
        currentDate: Date = Date(),
        recentSnapshots: [UsageSnapshot]
    ) -> Double {
        let hour = Double(Calendar.current.component(.hour, from: currentDate))
        let energy = energyAtHour(hour, profile: profile)
        let fatigue = fatiguePenalty(from: recentSnapshots, relativeTo: currentDate)
        return max(0, min(1, energy - fatigue))
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

    // MARK: - Private

    /// Gaussian blend of morning and evening energy peaks.
    /// Morning peaks around 9am, evening around 8pm.
    private func energyAtHour(_ hour: Double, profile: UserProfile) -> Double {
        let morningComponent = gaussian(hour, center: 9, width: 3) * profile.morningEnergy
        let eveningComponent = gaussian(hour, center: 20, width: 3) * profile.eveningEnergy
        // Afternoon dip (2pm) reduces both peaks
        let afternoonDip = 0.25 * gaussian(hour, center: 14, width: 2)
        return min(1, max(0, morningComponent + eveningComponent - afternoonDip))
    }

    /// Penalty based on social media / entertainment usage in the past 2 hours.
    /// Max penalty: 0.4 (at 2h of continuous social media).
    private func fatiguePenalty(from snapshots: [UsageSnapshot], relativeTo date: Date) -> Double {
        let cutoff = date.addingTimeInterval(-7200)
        let distractingSeconds = snapshots
            .filter { $0.timestamp > cutoff && isDistractingCategory($0.category) }
            .reduce(0.0) { $0 + $1.durationSeconds }
        return min(0.4, distractingSeconds / 7200.0 * 0.4)
    }

    private func gaussian(_ x: Double, center: Double, width: Double) -> Double {
        exp(-pow(x - center, 2) / (2 * pow(width, 2)))
    }

    private func isDistractingCategory(_ category: String) -> Bool {
        ["SocialNetworking", "Entertainment", "Games"].contains(category)
    }
}
