import XCTest
@testable import Window

final class ProfileAdapterTests: XCTestCase {
    var adapter: ProfileAdapter!
    var profile: UserProfile!

    override func setUp() {
        super.setUp()
        adapter = ProfileAdapter()
        profile = UserProfile()
        profile.morningEnergy = 0.6
        profile.eveningEnergy = 0.6
    }

    func test_acceptedMorningEventIncreaseMorningEnergy() {
        let before = profile.morningEnergy
        let event = makeEvent(timeOfDay: 0.375, outcome: .accepted)  // 9am
        adapter.adapt(profile: profile, event: event)
        XCTAssertGreaterThan(profile.morningEnergy, before)
        XCTAssertEqual(profile.eveningEnergy, 0.6, "Evening energy should be unchanged")
    }

    func test_skippedMorningEventDecreasesMorningEnergy() {
        let before = profile.morningEnergy
        let event = makeEvent(timeOfDay: 0.375, outcome: .skipped)
        adapter.adapt(profile: profile, event: event)
        XCTAssertLessThan(profile.morningEnergy, before)
    }

    func test_acceptedEveningEventIncreasesEveningEnergy() {
        let before = profile.eveningEnergy
        let event = makeEvent(timeOfDay: 0.833, outcome: .accepted)  // 8pm
        adapter.adapt(profile: profile, event: event)
        XCTAssertGreaterThan(profile.eveningEnergy, before)
        XCTAssertEqual(profile.morningEnergy, 0.6, "Morning energy should be unchanged")
    }

    func test_morningEnergyNeverDropsBelowMinimum() {
        profile.morningEnergy = 0.11
        for _ in 0..<100 {
            let event = makeEvent(timeOfDay: 0.375, outcome: .skipped)
            adapter.adapt(profile: profile, event: event)
        }
        XCTAssertGreaterThanOrEqual(profile.morningEnergy, 0.1)
    }

    func test_morningEnergyNeverExceedsMaximum() {
        profile.morningEnergy = 0.99
        for _ in 0..<100 {
            let event = makeEvent(timeOfDay: 0.375, outcome: .accepted)
            adapter.adapt(profile: profile, event: event)
        }
        XCTAssertLessThanOrEqual(profile.morningEnergy, 1.0)
    }

    // MARK: - Helpers

    private func makeEvent(timeOfDay: Double, outcome: RecommendationOutcome) -> RecommendationEvent {
        let event = RecommendationEvent(
            recommendedTaskName: "Test",
            recommendationText: "Test recommendation",
            productivityScore: 0.7,
            timeOfDay: timeOfDay
        )
        event.outcome = outcome
        return event
    }
}
