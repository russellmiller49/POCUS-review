import SwiftUI

struct ReviewQueueView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Review Queue", subtitle: "Prioritize cases based on urgency and submission time.")
                if appState.reviewQueue.isEmpty {
                    EmptyPlaceholderView(title: "Nothing to review", message: "You're all caught up. New submissions will appear here automatically.", systemImage: "checkmark.seal")
                } else {
                    ForEach(appState.reviewQueue) { caseData in
                        VStack(alignment: .leading, spacing: 16) {
                            CaseCardView(caseData: caseData, showFellowDetails: true, showAttendingDetails: false)
                            HStack {
                                NavigationLink {
                                    CaseDetailView(caseData: caseData)
                                } label: {
                                    Label("Quick View", systemImage: "eye")
                                }
                                Spacer()
                                NavigationLink {
                                    CaseReviewWithFeedbackView(caseData: caseData)
                                } label: {
                                    Label("Review & Provide Feedback", systemImage: "pencil.and.list.clipboard")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                        )
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
