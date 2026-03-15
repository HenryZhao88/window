import SwiftUI

struct FocusTimerView: View {
    var session: FocusSessionManager
    let onComplete: (Int) -> Void
    let onSkip: () -> Void
    let onBreakLogged: () -> Void

    @State private var showSkipConfirmation = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if session.state == .onBreak {
                breakView
            } else {
                focusView
            }
        }
        .confirmationDialog(
            "End this session?",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, end session", role: .destructive) {
                session.skip()
                onSkip()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your progress on this session will be lost.")
        }
    }

    // MARK: - Focus View

    private var focusView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Text(session.state == .paused ? "Paused" : "Focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let task = session.activeTask {
                    Text(task.name)
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 60)

            Spacer()

            timerRing

            Spacer()

            focusControls
                .padding(.bottom, 50)
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)
                .frame(width: 220, height: 220)

            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: session.progress)

            VStack(spacing: 4) {
                Text(timerLabel)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(ringColor)
                    .contentTransition(.numericText())
                    .animation(.none, value: session.elapsedSeconds)

                if session.isOvertime {
                    Text("overtime")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .textCase(.uppercase)
                        .tracking(1)
                } else if let task = session.activeTask {
                    Text("\(task.estimatedMinutes) min goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Controls

    private var focusControls: some View {
        VStack(spacing: 12) {
            // Done — most positive outcome, full width, prominent
            Button {
                let elapsed = session.complete()
                onComplete(elapsed)
            } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Pause / Resume — full width, secondary
            Button {
                if session.state == .running { session.pause() }
                else { session.resume() }
            } label: {
                Label(
                    session.state == .running ? "Pause" : "Resume",
                    systemImage: session.state == .running ? "pause.fill" : "play.fill"
                )
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 10) {
                // Break
                Button {
                    session.startBreak()
                    onBreakLogged()
                } label: {
                    Label("Break", systemImage: "cup.and.saucer.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Skip
                Button {
                    showSkipConfirmation = true
                } label: {
                    Label("End", systemImage: "xmark")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.red.opacity(0.08))
                        .foregroundStyle(.red.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Break View

    private var breakView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                VStack(spacing: 6) {
                    Text("Take a breather")
                        .font(.title2).bold()
                    Text("You've earned it. Come back when you're ready.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(formatTime(session.breakSeconds))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                    .animation(.none, value: session.breakSeconds)
            }

            Spacer()

            Button {
                session.endBreak()
            } label: {
                Label("End Break & Resume", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Helpers

    private var timerLabel: String {
        let remaining = session.remainingSeconds
        return remaining >= 0 ? formatTime(remaining) : "+\(formatTime(-remaining))"
    }

    private var ringColor: Color {
        if session.state == .paused { return .gray }
        if session.isOvertime { return .orange }
        return session.progress >= 0.8 ? .yellow : .blue
    }
}
