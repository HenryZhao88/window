import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var stage: Stage = .permissions

    enum Stage { case permissions, appSelection, goalConversation, productivityProfile }

    var body: some View {
        switch stage {
        case .permissions:
            PermissionsView { stage = .appSelection }
        case .appSelection:
            AppSelectionView { stage = .goalConversation }
        case .goalConversation:
            GoalConversationView { stage = .productivityProfile }
        case .productivityProfile:
            ProductivityProfileView { completeOnboarding() }
        }
    }

    private func completeOnboarding() {
        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }
        profile.onboardingComplete = true

        // Schedule the daily reminder now that we have a profile
        NotificationScheduler.shared.scheduleDailyReminder(for: profile)
    }
}
