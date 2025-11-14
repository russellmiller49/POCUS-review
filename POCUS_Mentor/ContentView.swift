import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.phase {
                case .loading:
                    ProgressView("Loading…")
                        .progressViewStyle(.circular)
                case .login:
                    LoginView()
                case .signup:
                    SignupView(institutions: viewModel.institutions)
                case .codeEntry(let email):
                    OTPVerificationView(email: email)
                case .selectingInstitution:
                    InstitutionSelectionView()
                case .selectingRole:
                    RoleSelectionView()
                case .dashboard:
                    DashboardView()
                case .pendingApproval:
                    PendingApprovalView()
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut, value: viewModel.phase)
        }
        .overlay(alignment: .top) {
            if let banner = viewModel.banner {
                ErrorBanner(message: banner.text) {
                    viewModel.dismissBanner()
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
