import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let email: String

    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Verification Code")
                    .font(.title.bold())
                Text("We sent a 6-digit code to \(email).")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("123456", text: $viewModel.otpCode)
                .keyboardType(.numberPad)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))

            Button(action: { Task { await viewModel.verifyOTP() } }) {
                if viewModel.isBusy {
                    ProgressView()
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.otpCode.count < 4 || viewModel.isBusy)

            Button("Resend Code") {
                Task { await viewModel.sendOTP() }
            }
            .disabled(viewModel.isBusy)

            Spacer()
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    OTPVerificationView(email: "demo@example.com")
        .environmentObject(AppViewModel())
}
