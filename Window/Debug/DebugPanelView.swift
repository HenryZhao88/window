#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications

struct DebugPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var tasks: [WindowTask]
    @Query private var snapshots: [UsageSnapshot]
    @Query private var events: [RecommendationEvent]

    @State private var hourOverride: Double = Double(Calendar.current.component(.hour, from: Date()))
    @State private var socialMinutesToInject: Double = 40
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Simulate") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Social media to inject")
                            Spacer()
                            Text("\(Int(socialMinutesToInject)) min")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $socialMinutesToInject, in: 0...120, step: 5)
                    }

                    Button("Inject Social Media Snapshot") {
                        injectFakeSnapshot()
                        toast("Injected \(Int(socialMinutesToInject))m of Instagram usage")
                    }

                    Button("Fire Test Notification") {
                        fireTestNotification()
                        toast("Notification scheduled in 1s")
                    }

                    Button("Trigger Recommendation Refresh") {
                        toast("Open the Today tab to see refreshed recommendation")
                    }
                }

                Section("Time Override") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Simulated hour")
                            Spacer()
                            Text("\(Int(hourOverride)):00")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $hourOverride, in: 0...23, step: 1)
                    }

                    if let profile = profiles.first {
                        let scorer = ProductivityScorer()
                        let fakeDate = Calendar.current.date(
                            bySettingHour: Int(hourOverride), minute: 0, second: 0, of: Date()
                        ) ?? Date()
                        let score = scorer.score(profile: profile, currentDate: fakeDate, recentSnapshots: snapshots)

                        HStack {
                            Text("Score at \(Int(hourOverride)):00")
                            Spacer()
                            Text(String(format: "%.2f — %@", score, scorer.label(for: score)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Reset") {
                    Button("Reset Onboarding", role: .destructive) {
                        profiles.forEach { modelContext.delete($0) }
                        toast("Onboarding reset — restart app")
                    }

                    Button("Delete All Snapshots", role: .destructive) {
                        snapshots.forEach { modelContext.delete($0) }
                        toast("Snapshots cleared")
                    }

                    Button("Delete All Events", role: .destructive) {
                        events.forEach { modelContext.delete($0) }
                        toast("Events cleared")
                    }
                }

                Section("Data Summary") {
                    if let profile = profiles.first {
                        NavigationLink("View Profile") { RawProfileView(profile: profile) }
                    }
                    StatRow(label: "Tasks", value: "\(tasks.count)")
                    StatRow(label: "Snapshots", value: "\(snapshots.count)")
                    StatRow(label: "Events", value: "\(events.count)")
                    StatRow(label: "Morning energy", value: profiles.first.map { String(format: "%.2f", $0.morningEnergy) } ?? "—")
                    StatRow(label: "Evening energy", value: profiles.first.map { String(format: "%.2f", $0.eveningEnergy) } ?? "—")
                }
            }
            .navigationTitle("Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray2))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastMessage != nil)
        }
    }

    // MARK: - Actions

    private func injectFakeSnapshot() {
        let snapshot = UsageSnapshot(
            appBundleID: "com.burbn.instagram",
            category: "SocialNetworking",
            durationSeconds: socialMinutesToInject * 60
        )
        modelContext.insert(snapshot)
    }

    private func fireTestNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Window"
            content.body = "Test: Your focus window is open. Time to get to work!"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func toast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            toastMessage = nil
        }
    }
}

struct RawProfileView: View {
    let profile: UserProfile

    var body: some View {
        List {
            Section("Goals") {
                LabeledContent("10-Year Goal", value: profile.tenYearGoal.isEmpty ? "—" : profile.tenYearGoal)
                LabeledContent("Weekly Focus", value: profile.weeklyFocus.isEmpty ? "—" : profile.weeklyFocus)
                LabeledContent("Key Habits", value: profile.keyHabits.joined(separator: ", "))
            }
            Section("Profile") {
                LabeledContent("Chronotype", value: profile.chronotype.displayName)
                LabeledContent("Focus Duration", value: "\(profile.focusDuration) min")
                LabeledContent("Morning Energy", value: String(format: "%.2f", profile.morningEnergy))
                LabeledContent("Evening Energy", value: String(format: "%.2f", profile.eveningEnergy))
                LabeledContent("Procrastination", value: String(format: "%.2f", profile.procrastinationTendency))
                LabeledContent("Onboarding", value: profile.onboardingComplete ? "Complete" : "Pending")
            }
        }
        .navigationTitle("Raw Profile")
    }
}
#endif
