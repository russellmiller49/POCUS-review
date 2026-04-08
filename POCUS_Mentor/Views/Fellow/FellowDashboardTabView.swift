import SwiftUI

struct FellowDashboardTabView: View {
    var body: some View {
        TabView {
            FellowExperienceView()
                .tabItem { Label("Queue", systemImage: "tray") }

            StudyHomeView()
                .tabItem { Label("Studies", systemImage: "doc.on.doc") }

            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    FellowDashboardTabView()
        .environmentObject(AppViewModel())
}
