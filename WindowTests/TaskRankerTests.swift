import XCTest
@testable import Window

final class TaskRankerTests: XCTestCase {
    var ranker: TaskRanker!

    override func setUp() {
        super.setUp()
        ranker = TaskRanker()
    }

    func test_noTasks_returnsNil() {
        let result = ranker.topTask(from: [], productivityScore: 0.8)
        XCTAssertNil(result)
    }

    func test_completedTasksAreExcluded() {
        let task = WindowTask(name: "Done", difficulty: 0.9, deadline: Date(), estimatedMinutes: 60)
        task.isCompleted = true
        let result = ranker.topTask(from: [task], productivityScore: 0.8)
        XCTAssertNil(result)
    }

    func test_urgentTaskRanksHigher() {
        let urgent = WindowTask(
            name: "Due tomorrow",
            difficulty: 0.5,
            deadline: Date().addingTimeInterval(86400),
            estimatedMinutes: 30
        )
        let distant = WindowTask(
            name: "Due in a month",
            difficulty: 0.5,
            deadline: Date().addingTimeInterval(86400 * 30),
            estimatedMinutes: 30
        )
        let top = ranker.topTask(from: [distant, urgent], productivityScore: 0.7)
        XCTAssertEqual(top?.name, "Due tomorrow")
    }

    func test_overdueTaskGetsMaxUrgency() {
        let overdue = WindowTask(
            name: "Overdue",
            difficulty: 0.3,
            deadline: Date().addingTimeInterval(-86400),
            estimatedMinutes: 30
        )
        let upcoming = WindowTask(
            name: "Upcoming",
            difficulty: 0.8,
            deadline: Date().addingTimeInterval(86400 * 7),
            estimatedMinutes: 60
        )
        let top = ranker.topTask(from: [upcoming, overdue], productivityScore: 0.7)
        XCTAssertEqual(top?.name, "Overdue")
    }

    func test_taskScoreIsNonNegative() {
        let task = WindowTask(name: "Test", difficulty: 0.5, deadline: Date().addingTimeInterval(86400), estimatedMinutes: 45)
        let score = ranker.taskScore(task, productivityScore: 0.6)
        XCTAssertGreaterThanOrEqual(score, 0)
    }
}
