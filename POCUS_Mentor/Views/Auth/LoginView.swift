import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("POCUS Mentor")
                    .font(.largeTitle.bold())
                Text("Sign in with your institutional email to receive a one-time passcode.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("name@example.com", text: $viewModel.email)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))

            Button(action: { Task { await viewModel.sendOTP() } }) {
                if viewModel.isBusy {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.email.isEmpty || viewModel.isBusy)
            
            HStack(spacing: 16) {
                Button("Don't have an account? Sign up") {
                    Task {
                        await viewModel.presentSignup()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Button("TestFlight Reviewer") {
                    viewModel.presentReviewerLogin()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel())
}
