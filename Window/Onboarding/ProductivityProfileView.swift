import SwiftUI
import SwiftData

struct ProductivityProfileView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var chronotype: Chronotype = .flexible
    @State private var focusDuration: Int = 45
    @State private var procrastinationSlider: Double = 0.5  // 0=last-minute, 1=early bird

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("How do you work?")
                        .font(.largeTitle).bold()
                    Text("Window uses this to schedule your day around your natural rhythms.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Chronotype picker
                VStack(alignment: .leading, spacing: 14) {
                    Label("When do you feel most alive?", systemImage: "sun.max")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(Chronotype.allCases, id: \.self) { type in
                            Button {
                                chronotype = type
                            } label: {
                                HStack {
                                    Text(type.displayName)
                                    Spacer()
                                    if chronotype == type {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding()
                                .background(chronotype == type ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                // Focus duration
                VStack(alignment: .leading, spacing: 14) {
                    Label("How long can you focus before a break?", systemImage: "timer")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                        ForEach([15, 25, 45, 60, 90, 120], id: \.self) { mins in
                            Button {
                                focusDuration = mins
                            } label: {
                                Text(formatDuration(mins))
                                    .font(.subheadline).bold()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(focusDuration == mins ? Color.blue : Color(.systemGray6))
                                    .foregroundStyle(focusDuration == mins ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                // Procrastination
                VStack(alignment: .leading, spacing: 14) {
                    Label("How far in advance do you start things?", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    VStack(spacing: 4) {
                        Slider(value: $procrastinationSlider, in: 0...1)
                            .tint(.blue)
                        HStack {
                            Text("Day before").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Weeks early").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Text(procrastinationLabel)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Spacer(minLength: 20)

                Button {
                    saveAndFinish()
                } label: {
                    Text("Start using Window →")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    private func formatDuration(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        let remaining = mins % 60
        return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
    }

    private var procrastinationLabel: String {
        switch procrastinationSlider {
        case 0..<0.33: return "Last-minute finisher — Window will remind you earlier"
        case 0.33..<0.66: return "Gets it done on time — steady and reliable"
        default: return "Early bird planner — Window will give you breathing room"
        }
    }

    private func saveAndFinish() {
        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }

        profile.chronotype = chronotype
        profile.focusDuration = focusDuration
        profile.procrastinationTendency = 1.0 - procrastinationSlider  // 1 = high procrastination

        switch chronotype {
        case .morning:
            profile.morningEnergy = 0.85
            profile.eveningEnergy = 0.40
        case .evening:
            profile.morningEnergy = 0.30
            profile.eveningEnergy = 0.85
        case .flexible:
            profile.morningEnergy = 0.65
            profile.eveningEnergy = 0.65
        }

        onComplete()
    }
}
