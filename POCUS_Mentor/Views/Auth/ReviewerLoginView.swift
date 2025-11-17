import SwiftUI

struct ReviewerLoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TestFlight Reviewer Login")
                    .font(.largeTitle.bold())
                Text("Select a role to test the app as an App Store reviewer.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                ReviewerRoleButton(
                    role: "Fellow",
                    description: "Test as a fellow creating and submitting studies",
                    icon: "person.fill"
                ) {
                    Task { await viewModel.signInAsReviewer(role: "fellow") }
                }
                
                ReviewerRoleButton(
                    role: "Attending",
                    description: "Test as an attending reviewing studies",
                    icon: "stethoscope"
                ) {
                    Task { await viewModel.signInAsReviewer(role: "attending") }
                }
                
                ReviewerRoleButton(
                    role: "Admin",
                    description: "Test as an administrator managing the program",
                    icon: "person.badge.shield.checkmark.fill"
                ) {
                    Task { await viewModel.signInAsReviewer(role: "admin") }
                }
            }
            
            Button("Back to Regular Login") {
                viewModel.presentLogin()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.top, 16)
            
            Spacer()
        }
        .padding(.vertical, 40)
    }
}

private struct ReviewerRoleButton: View {
    let role: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(role)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReviewerLoginView()
        .environmentObject(AppViewModel())
}

