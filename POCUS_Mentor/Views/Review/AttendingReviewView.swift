import SwiftUI

struct AttendingReviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedStudy: Study?
    @State private var selection: ReviewTab = .queue

    enum ReviewTab: String, CaseIterable, Identifiable {
        case queue
        case returned
        case accepted

        var id: String { rawValue }

        var title: String {
            switch self {
            case .queue: return "Queue"
            case .returned: return "Returned"
            case .accepted: return "Accepted"
            }
        }

        var emptyMessage: (title: String, description: String, systemImage: String) {
            switch self {
            case .queue:
                return ("Nothing to review", "When fellows submit studies they will appear here.", "tray")
            case .returned:
                return ("No returned studies", "Cases you send back for revisions show up here until resubmitted.", "arrow.uturn.left")
            case .accepted:
                return ("No accepted studies", "Approved or signed off cases will appear here.", "checkmark.seal")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(selection == .queue ? "Review Queue" : selection.title)
                    .font(.largeTitle.bold())
                Spacer()
                RefreshButton(isBusy: viewModel.isBusy) {
                    Task { await viewModel.refreshStudies() }
                }
            }

            if let sessionDescription {
                Text(sessionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker("Review filter", selection: $selection) {
                ForEach(ReviewTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.currentSession?.role != .attending {
                ContentUnavailableView(
                    "Attending Access Required",
                    systemImage: "lock.fill",
                    description: Text("Only attending users can access the review queue.")
                )
            } else if studies.isEmpty {
                let empty = selection.emptyMessage
                ContentUnavailableView(empty.title, systemImage: empty.systemImage, description: Text(empty.description))
            } else {
                List(studies, id: \.id) { study in
                    Button {
                        selectedStudy = study
                    } label: {
                        ReviewRow(study: study, tab: selection)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.refreshStudies()
                }
            }
        }
        .padding(.vertical)
        .sheet(item: $selectedStudy) { study in
            ReviewDetailView(study: study)
        }
    }

    private var sessionDescription: String? {
        guard let session = viewModel.currentSession else { return nil }
        return "\(session.institutionName) • \(session.role.displayName)"
    }
}

extension AttendingReviewView {
    private var studies: [Study] {
        switch selection {
        case .queue:
            return viewModel.reviewQueue
        case .returned:
            return viewModel.returnedReviews
        case .accepted:
            return viewModel.acceptedReviews
        }
    }
}

private struct ReviewRow: View {
    let study: Study
    let tab: AttendingReviewView.ReviewTab

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(study.examType)
                    .font(.headline)
                if let submitted = study.submittedAt {
                    Text(submitted.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if tab != .queue {
                    StatusChip(status: study.status)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AttendingReviewView()
        .environmentObject(AppViewModel())
}
