import SwiftUI

struct RoleExperienceContainer: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole
    
    var body: some View {
        Group {
            switch role {
            case .fellow:
                FellowExperienceView()
            case .attending:
                AttendingExperienceView()
            case .administrator:
                AdministratorExperienceView()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var title: String {
        switch role {
        case .fellow:
            return "Fellow Workspace"
        case .attending:
            return "Attending Dashboard"
        case .administrator:
            return "Program Command"
        }
    }
}

#Preview {
    RoleExperienceContainer(role: .fellow)
        .environmentObject(AppState())
}
