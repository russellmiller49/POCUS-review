import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            if let group = viewModel.roleSelectionGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.institution.name)
                        .font(.title2.bold())
                    Text("Select which role to open for this institution.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                List(group.memberships, id: \.id) { membership in
                    Button {
                        Task { await viewModel.selectMembership(membership) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(membership.membership.membershipRole.displayName)
                                    .font(.headline)
                                Text(membership.membership.role.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button("Choose Another Institution") {
                    viewModel.presentInstitutionSelection()
                }
                .buttonStyle(.bordered)
            } else {
                ProgressView("Loading roles…")
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal)
    }
}

#Preview {
    RoleSelectionView()
        .environmentObject(AppViewModel())
}
