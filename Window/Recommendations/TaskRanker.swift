import Foundation

struct TaskRanker {

    /// Returns the highest-scoring pending task, or nil if none exist.
    func topTask(from tasks: [WindowTask], productivityScore: Double) -> WindowTask? {
        tasks
            .filter { !$0.isCompleted }
            .max { taskScore($0, productivityScore: productivityScore) < taskScore($1, productivityScore: productivityScore) }
    }

    func taskScore(_ task: WindowTask, productivityScore: Double) -> Double {
        productivityScore * importance(of: task)
    }

    /// Importance: weighted blend of deadline urgency (50%), difficulty (30%), size (20%).
    func importance(of task: WindowTask) -> Double {
        let urgency = deadlineUrgency(task.deadline)
        let size = min(1.0, Double(task.estimatedMinutes) / 120.0)
        return urgency * 0.5 + task.difficulty * 0.3 + size * 0.2
    }

    // MARK: - Private

    /// 1.0 when due today, decays logarithmically to 0 at 30 days out.
    private func deadlineUrgency(_ deadline: Date) -> Double {
        let days = max(0, deadline.timeIntervalSinceNow / 86400)
        guard days > 0 else { return 1.0 }
        return max(0, 1.0 - log(days + 1) / log(31))
    }
}
