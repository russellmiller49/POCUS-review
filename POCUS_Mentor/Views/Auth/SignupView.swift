import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    @State private var fullName: String = ""
    @State private var selectedInstitution: Institution?
    @State private var selectedRole: MembershipRole = .fellow
    @State private var selectedPGY: String = "PGY-4"
    
    let institutions: [Institution]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle.bold())
                    Text("Sign up with your personal email to get started.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.subheadline.bold())
                    TextField("Dr. Jane Doe", text: $fullName)
                        .textContentType(.name)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                }

                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline.bold())
                    TextField("name@example.com", text: $viewModel.email)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                }
                
                // Institution Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Institution")
                        .font(.subheadline.bold())
                    if institutions.isEmpty {
                        HStack {
                            Text("Loading institutions…")
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                        .disabled(true)
                    } else {
                        Menu {
                            ForEach(institutions) { institution in
                                Button(action: {
                                    selectedInstitution = institution
                                }) {
                                    HStack {
                                        Text(institution.name)
                                        if selectedInstitution?.id == institution.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedInstitution?.name ?? "Select Institution")
                                    .foregroundColor(selectedInstitution == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                            .contentShape(Rectangle())
                        }
                    }
                }
                
                // Role Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.subheadline.bold())
                    Picker("Role", selection: $selectedRole) {
                        ForEach([MembershipRole.fellow, MembershipRole.attending, MembershipRole.administrator], id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // PGY Year Selection (only for Fellows)
                if selectedRole == .fellow {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Year of Training")
                            .font(.subheadline.bold())
                        Picker("PGY Year", selection: $selectedPGY) {
                            Text("PGY-4").tag("PGY-4")
                            Text("PGY-5").tag("PGY-5")
                            Text("PGY-6").tag("PGY-6")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // Approval Message for Attending/Admin
                if selectedRole == .attending || selectedRole == .administrator {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Role Approval Required")
                                .font(.subheadline.bold())
                        }
                        Text("Your \(selectedRole.displayName.lowercased()) role request will be reviewed by an administrator. You will receive access once your role is approved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
                }
                
                // Sign Up Button
                Button(action: { 
                    Task { 
                        await viewModel.signup(
                            name: fullName,
                            institution: selectedInstitution,
                            role: selectedRole,
                            pgyYear: selectedRole == .fellow ? selectedPGY : nil
                        ) 
                    }
                }) {
                    if viewModel.isBusy {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    fullName.isEmpty ||
                    selectedInstitution == nil || 
                    viewModel.email.isEmpty ||
                    viewModel.isBusy
                )
                
                // Back to Login
                Button("Already have an account? Sign in") {
                    viewModel.presentLogin()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .task {
                if institutions.isEmpty {
                    await viewModel.loadInstitutions()
                }
            }
            .padding(.vertical, 40)
            .padding(.horizontal)
        }
    }
}

#Preview {
    SignupView(institutions: [
        Institution(id: UUID(), slug: "nmcsd", name: "Naval Medical Center San Diego", settings: .null),
        Institution(id: UUID(), slug: "ucsd", name: "University of California San Diego", settings: .null)
    ])
    .environmentObject(AppViewModel())
}














