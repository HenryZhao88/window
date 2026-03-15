import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RecommendationView()
                .tabItem {
                    Label("Today", systemImage: "sparkles")
                }

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            UsageInsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
