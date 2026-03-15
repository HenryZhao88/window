import Foundation
import Observation

@Observable
@MainActor
final class FocusSessionManager {

    enum SessionState: Equatable {
        case idle
        case running
        case paused
        case onBreak
    }

    private(set) var state: SessionState = .idle
    private(set) var activeTask: WindowTask?
    private(set) var elapsedSeconds: Int = 0
    private(set) var breakSeconds: Int = 0

    var isActive: Bool { state != .idle }

    var totalSeconds: Int { (activeTask?.estimatedMinutes ?? 0) * 60 }

    /// Remaining seconds. Negative when overtime.
    var remainingSeconds: Int { totalSeconds - elapsedSeconds }

    var isOvertime: Bool { elapsedSeconds > totalSeconds && totalSeconds > 0 }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(totalSeconds))
    }

    private var timerTask: Task<Void, Never>?

    // MARK: - Controls

    func start(task: WindowTask) {
        cancelTimer()
        activeTask = task
        elapsedSeconds = 0
        breakSeconds = 0
        state = .running
        tick()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        cancelTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        tick()
    }

    func startBreak() {
        cancelTimer()
        breakSeconds = 0
        state = .onBreak
        tickBreak()
    }

    func endBreak() {
        cancelTimer()
        state = .running
        tick()
    }

    /// Returns elapsed seconds so the caller can log it, then resets.
    func complete() -> Int {
        let elapsed = elapsedSeconds
        reset()
        return elapsed
    }

    func skip() { reset() }

    // MARK: - Private

    private func tick() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.elapsedSeconds += 1 }
            }
        }
    }

    private func tickBreak() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.breakSeconds += 1 }
            }
        }
    }

    private func cancelTimer() { timerTask?.cancel(); timerTask = nil }

    private func reset() {
        cancelTimer()
        state = .idle
        activeTask = nil
        elapsedSeconds = 0
        breakSeconds = 0
    }
}

// MARK: - Formatting helpers

func formatTime(_ totalSeconds: Int) -> String {
    let abs = Swift.abs(totalSeconds)
    let m = abs / 60
    let s = abs % 60
    return String(format: "%02d:%02d", m, s)
}
