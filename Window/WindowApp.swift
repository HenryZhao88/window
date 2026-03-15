import SwiftUI
import SwiftData

@main
struct WindowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(SharedModelContainer.makeContainer())
        }
    }
}

struct RootView: View {
    @AppStorage("openai_api_key") private var apiKey = ""
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if apiKey.isEmpty {
                APIKeySetupView()
            } else if profiles.first?.onboardingComplete != true {
                OnboardingFlow()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            ScreenTimeService.shared.checkStatus()
        }
    }
}
