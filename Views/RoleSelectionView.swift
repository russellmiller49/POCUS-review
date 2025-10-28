import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your workspace")
                        .font(.largeTitle.bold())
                    Text("POCUS Mentor tailors tools, analytics, and feedback workflows for each role in the echo education journey.")
                        .foregroundStyle(.secondary)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                    ForEach(UserRole.allCases) { role in
                        RoleSelectionCard(role: role) {
                            appState.selectedRole = role
                            if role == .fellow {
                                appState.selectedFellow = appState.fellows.first
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

private struct RoleSelectionCard: View {
    let role: UserRole
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: role.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .padding(12)
                        .background(role.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                }
                
                Text(role.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 6) {
                    Text("Enter workspace")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(role.accentColor)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var description: String {
        switch role {
        case .fellow:
            return "Submit cases, review feedback, and track your ultrasound learning milestones."
        case .attending:
            return "Prioritize review queue, annotate studies, and deliver structured feedback."
        case .administrator:
            return "Monitor program metrics, compliance, and educational impact in one place."
        }
    }
}

#Preview {
    RoleSelectionView()
        .environmentObject(AppState())
}
