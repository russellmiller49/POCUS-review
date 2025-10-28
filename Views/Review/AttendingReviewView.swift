import SwiftUI

struct AttendingReviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedStudy: Study?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Queue")
                .font(.largeTitle.bold())

            if viewModel.currentSession?.role != .attending {
                ContentUnavailableView(
                    "Attending Access Required",
                    systemImage: "lock.fill",
                    description: Text("Only attending users can access the review queue.")
                )
            } else if viewModel.reviewQueue.isEmpty {
                ContentUnavailableView(
                    "Nothing to review",
                    systemImage: "tray",
                    description: Text("When fellows submit studies they will appear here.")
                )
            } else {
                List(viewModel.reviewQueue, id: \.id) { study in
                    Button {
                        selectedStudy = study
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(study.examType)
                                    .font(.headline)
                                if let submitted = study.submittedAt {
                                    Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .padding(.vertical)
        .sheet(item: $selectedStudy) { study in
            ReviewDetailView(study: study)
        }
    }
}

#Preview {
    AttendingReviewView()
        .environmentObject(AppViewModel())
}
