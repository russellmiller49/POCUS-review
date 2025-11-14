import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var tabSelection: Tab = .experience
    @State private var hasPresentedExperience = false

    enum Tab: Hashable {
        case experience
        case studies
        case review
        case settings
    }

    var body: some View {
        TabView(selection: $tabSelection) {
            if let role = userRole {
                RoleExperienceContainer(role: role)
                    .tabItem {
                        Label(experienceTitle, systemImage: experienceIcon)
                    }
                    .tag(Tab.experience)
            } else {
                ProgressView("Loading role…")
                    .tabItem { Label(experienceTitle, systemImage: experienceIcon) }
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
        .task {
            autoSelectExperienceIfNeeded()
        }
        .onChange(of: userRole) { _, _ in
            autoSelectExperienceIfNeeded()
        }
        .sheet(item: Binding(
            get: { viewModel.studyDetail },
            set: { newValue in
                if newValue == nil { viewModel.dismissStudyDetail() }
            })
        ) { detail in
            StudyDetailView(detail: detail)
        }
    }

    private var userRole: UserRole? {
        viewModel.currentSession?.role.userRole
    }

    private var experienceTitle: String {
        userRole?.displayName ?? "Experience"
    }

    private var experienceIcon: String {
        userRole?.systemImage ?? "person.circle"
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
