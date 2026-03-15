import Foundation

/// Updates UserProfile adaptive weights based on recommendation outcomes.
/// Uses Exponential Moving Average (EMA) with alpha = 0.1.
struct ProfileAdapter {
    private let alpha = 0.1
    private let step = 0.05
    private let minEnergy = 0.1
    private let maxEnergy = 1.0

    func adapt(profile: UserProfile, event: RecommendationEvent) {
        let hour = event.timeOfDay * 24

        switch event.outcome {
        case .accepted:
            // Positive signal: nudge energy up at this time of day
            if hour < 13 {
                profile.morningEnergy = clamp(profile.morningEnergy + alpha * step)
            } else {
                profile.eveningEnergy = clamp(profile.eveningEnergy + alpha * step)
            }

        case .skipped, .breakTaken:
            // Negative signal: nudge energy down at this time of day
            if hour < 13 {
                profile.morningEnergy = clamp(profile.morningEnergy - alpha * step)
            } else {
                profile.eveningEnergy = clamp(profile.eveningEnergy - alpha * step)
            }
        }
    }

    private func clamp(_ value: Double) -> Double {
        max(minEnergy, min(maxEnergy, value))
    }
}
