import SwiftUI

struct FellowFeedbackView: View {
    @EnvironmentObject private var appState: AppState
    
    private var reviewedCases: [POCUSCase] {
        appState.filteredCases.filter { $0.feedback != nil }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Annotated Feedback", subtitle: "Deep dive into teaching points and visual markup from your mentors.")
                if reviewedCases.isEmpty {
                    EmptyPlaceholderView(title: "No feedback available", message: "Once an attending responds you'll receive annotations, teaching pearls, and resource links here.", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                } else {
                    ForEach(reviewedCases) { caseData in
                        VStack(alignment: .leading, spacing: 16) {
                            CaseCardView(caseData: caseData, showFellowDetails: false)
                            FeedbackSummaryCard(caseData: caseData)
                            if let feedback = caseData.feedback {
                                FeedbackDetailView(feedback: feedback)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
