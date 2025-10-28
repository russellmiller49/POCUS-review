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
                case .codeEntry(let email):
                    OTPVerificationView(email: email)
                case .selectingInstitution:
                    InstitutionSelectionView()
                case .dashboard:
                    DashboardView()
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut, value: viewModel.phase)
            .toolbar {
                if case .dashboard = viewModel.phase,
                   let session = viewModel.currentSession {
                    ToolbarItem(placement: .navigationBarLeading) {
                        VStack(alignment: .leading) {
                            Text(session.institutionName)
                                .font(.headline)
                            Text(session.role.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
