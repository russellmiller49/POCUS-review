import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var appState: AppState
    @State private var tabSelection: Tab = .studies
    @State private var hasPresentedExperience = false

    enum Tab: Hashable {
        case experience
        case studies
        case review
        case settings
    }

    var body: some View {
        TabView(selection: $tabSelection) {
            if let userRole {
                RoleExperienceContainer(role: userRole)
                    .tabItem {
                        Label(userRole.displayName, systemImage: userRole.systemImage)
                    }
                    .tag(Tab.experience)
            }

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
        .onAppear {
            syncExperienceRole()
            autoSelectExperienceIfNeeded()
        }
        .onChange(of: viewModel.currentSession?.role) { _ in
            syncExperienceRole()
            autoSelectExperienceIfNeeded()
        }
    }

    private var userRole: UserRole? {
        viewModel.currentSession?.role.userRole
    }

    private func syncExperienceRole() {
        guard let role = userRole else {
            appState.resetState()
            return
        }
        if appState.selectedRole != role {
            appState.selectedRole = role
        }
    }

    private func autoSelectExperienceIfNeeded() {
        guard userRole != nil, hasPresentedExperience == false else { return }
        tabSelection = .experience
        hasPresentedExperience = true
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppViewModel())
        .environmentObject(AppState())
}

private extension MembershipRole {
    var userRole: UserRole {
        switch self {
        case .fellow:
            return .fellow
        case .attending:
            return .attending
        case .administrator, .admin:
            return .administrator
        }
    }
}
