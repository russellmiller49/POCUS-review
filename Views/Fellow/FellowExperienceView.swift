import SwiftUI

struct FellowExperienceView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            FellowDashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            FellowCasesView()
                .tabItem { Label("My Cases", systemImage: "folder") }
            if let fellow = appState.selectedFellow {
                PortfolioProgressView(fellow: fellow)
                    .tabItem { Label("Portfolio", systemImage: "chart.bar.doc.horizontal") }
            }
            FellowFeedbackView()
                .tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill") }
            FellowAnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
            ResourcesLibraryView()
                .tabItem { Label("Resources", systemImage: "book.pages") }
        }
        .overlay(alignment: .bottomTrailing) {
            if appState.selectedRole == .fellow {
                FloatingActionButton(systemImage: "plus", title: "New Case") {
                    appState.showCreateCaseFlow = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
                .sheet(isPresented: $appState.showCreateCaseFlow) {
                    CaseUploadWizard()
                }
            }
        }
    }
}
