import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            if let session = viewModel.currentSession {
                Section("Account") {
                    Text(session.profile.email)
                    Text(session.role.displayName)
                    Text(session.institutionName)
                }
            }

            Section("Preferences") {
                Toggle("De-identification Attestation", isOn: .init(
                    get: { UserDefaults.standard.bool(forKey: "pocus.deidentificationAcknowledged") },
                    set: { UserDefaults.standard.set($0, forKey: "pocus.deidentificationAcknowledged") }
                ))
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }

            Section {
                Button(role: .destructive) {
                    Task { await viewModel.signOut() }
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
