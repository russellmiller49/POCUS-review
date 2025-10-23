import SwiftUI

struct InstitutionSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Institution")
                    .font(.title.bold())
                Text("Select which institution workspace to open.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List(viewModel.memberships, id: \.id) { membership in
                Button {
                    Task { await viewModel.selectMembership(membership) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(membership.institution.name)
                                .font(.headline)
                            Text(membership.membership.membershipRole.displayName)
                                .font(.subheadline)
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
        }
        .padding(.vertical, 32)
    }
}

#Preview {
    InstitutionSelectionView()
        .environmentObject(AppViewModel())
}
