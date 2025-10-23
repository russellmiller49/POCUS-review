import SwiftUI

struct ReviewDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let study: Study

    @State private var rating: Int = 3
    @State private var comments: String = ""
    @State private var signoffStatus: SignoffStatus = .approved

    var body: some View {
        NavigationStack {
            Form {
                Section("Study") {
                    Text(study.examType)
                    if let submitted = study.submittedAt {
                        Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Assessment") {
                    Stepper(value: $rating, in: 1...5) {
                        Label("Rating \(rating)/5", systemImage: "star.fill")
                    }
                    TextEditor(text: $comments)
                        .frame(height: 120)
                }

                Section("Sign-off") {
                    Picker("Status", selection: $signoffStatus) {
                        Text("Approve").tag(SignoffStatus.approved)
                        Text("Needs Revision").tag(SignoffStatus.revisions)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submitReview(
                                for: study,
                                rating: rating,
                                comments: comments,
                                signoffStatus: signoffStatus
                            )
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .task {
            await viewModel.loadStudyDetail(for: study)
        }
    }
}

#Preview {
    ReviewDetailView(
        study: Study(
            id: UUID(),
            institutionId: UUID(),
            createdBy: UUID(),
            examType: "Focused Vascular",
            status: .submitted,
            submittedAt: .now,
            notes: nil,
            createdAt: .now
        )
    )
    .environmentObject(AppViewModel())
}
