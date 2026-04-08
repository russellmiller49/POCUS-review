import SwiftUI

struct AdministratorExperienceView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ProgramOverviewView()
            }
            .tabItem { Label("Overview", systemImage: "chart.bar.doc.horizontal") }
            
            NavigationStack {
                ResourcesLibraryView()
            }
            .tabItem { Label("Resources", systemImage: "book") }
        }
    }
}
