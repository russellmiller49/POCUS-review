import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var tabSelection: Tab = .studies

    enum Tab: Hashable {
        case studies
        case review
        case settings
    }

    var body: some View {
        TabView(selection: $tabSelection) {
            StudyHomeView()
                .tabItem { Label("Studies", systemImage: "doc.on.doc") }
                .tag(Tab.studies)

            AttendingReviewView()
                .tabItem { Label("Review", systemImage: "checkmark.circle") }
                .tag(Tab.review)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppViewModel())
}
