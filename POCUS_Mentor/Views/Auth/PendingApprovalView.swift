import SwiftUI

struct PendingApprovalView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Role Approval Pending")
                    .font(.title.bold())
                
                Text("Your role request has been submitted and is awaiting approval by an administrator.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Account created successfully")
                }
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Role request submitted")
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("Waiting for administrator approval")
                }
            }
            .font(.subheadline)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            
            Text("You will receive an email notification once your role has been approved and you can access the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Sign Out") {
                Task {
                    await viewModel.signOut()
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    PendingApprovalView()
        .environmentObject(AppViewModel())
}


