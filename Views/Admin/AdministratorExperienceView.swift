import SwiftUI

struct AdministratorExperienceView: View {
    var body: some View {
        TabView {
            ProgramOverviewView()
                .tabItem { Label("Overview", systemImage: "chart.bar.doc.horizontal") }
            ReportsWorkspaceView()
                .tabItem { Label("Reports", systemImage: "doc.text.magnifyingglass") }
            ComplianceCenterView()
                .tabItem { Label("Compliance", systemImage: "lock.shield") }
            ResourcesLibraryView()
                .tabItem { Label("Resources", systemImage: "book") }
        }
    }
}
