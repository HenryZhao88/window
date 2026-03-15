import XCTest
@testable import Window

final class ProductivityScorerTests: XCTestCase {
    var scorer: ProductivityScorer!
    var profile: UserProfile!

    override func setUp() {
        super.setUp()
        scorer = ProductivityScorer()
        profile = UserProfile()
        profile.morningEnergy = 0.85
        profile.eveningEnergy = 0.40
    }

    func test_score_isInValidRange() {
        let date = makeDate(hour: 9)
        let score = scorer.score(profile: profile, currentDate: date, recentSnapshots: [])
        XCTAssertGreaterThanOrEqual(score, 0.0)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    func test_morningPerson_highScoreAtNineAM() {
        let date = makeDate(hour: 9)
        let score = scorer.score(profile: profile, currentDate: date, recentSnapshots: [])
        XCTAssertGreaterThan(score, 0.5, "Morning person should have high score at 9am")
    }

    func test_morningPerson_lowerScoreAtNight() {
        let morningScore = scorer.score(profile: profile, currentDate: makeDate(hour: 9), recentSnapshots: [])
        let nightScore = scorer.score(profile: profile, currentDate: makeDate(hour: 23), recentSnapshots: [])
        XCTAssertGreaterThan(morningScore, nightScore)
    }

    func test_socialMediaFatigueReducesScore() {
        let date = makeDate(hour: 9)

        let noDistraction = scorer.score(profile: profile, currentDate: date, recentSnapshots: [])

        let heavyDistraction = UsageSnapshot(
            appBundleID: "com.burbn.instagram",
            category: "SocialNetworking",
            durationSeconds: 7200  // 2 hours
        )
        heavyDistraction.timestamp = date.addingTimeInterval(-3600)

        let withDistraction = scorer.score(profile: profile, currentDate: date, recentSnapshots: [heavyDistraction])
        XCTAssertGreaterThan(noDistraction, withDistraction)
    }

    func test_fatiguePenaltyMaxIs04() {
        let date = makeDate(hour: 9)
        // 4 hours of social media — penalty should cap at 0.4
        let snapshots = (0..<4).map { i -> UsageSnapshot in
            let s = UsageSnapshot(appBundleID: "test", category: "SocialNetworking", durationSeconds: 3600)
            s.timestamp = date.addingTimeInterval(Double(-i) * 60)
            return s
        }
        let score = scorer.score(profile: profile, currentDate: date, recentSnapshots: snapshots)
        let scoreWithoutFatigue = scorer.score(profile: profile, currentDate: date, recentSnapshots: [])
        let penaltyApplied = scoreWithoutFatigue - score
        XCTAssertLessThanOrEqual(penaltyApplied, 0.401)  // tolerance for floating point
    }

    func test_label_highFocus() {
        XCTAssertEqual(scorer.label(for: 0.8), "High Focus")
    }

    func test_label_moderate() {
        XCTAssertEqual(scorer.label(for: 0.5), "Moderate")
    }

    func test_label_lowEnergy() {
        XCTAssertEqual(scorer.label(for: 0.2), "Low Energy")
    }

    // MARK: - Helpers

    private func makeDate(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }
}
