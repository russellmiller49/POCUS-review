import SwiftUI

struct FellowFeedbackView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    private var feedbackItems: [(Study, [Feedback])] {
        viewModel.myStudies.compactMap { study in
            let feedback = viewModel.feedback(for: study)
            return feedback.isEmpty ? nil : (study, feedback)
        }
        .sorted { lhs, rhs in
            guard let leftDate = lhs.1.first?.createdAt, let rightDate = rhs.1.first?.createdAt else {
                return lhs.0.createdAt > rhs.0.createdAt
            }
            return leftDate > rightDate
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "Annotated Feedback",
                    subtitle: "Review teaching points and comments tied to your studies."
                )
                if feedbackItems.isEmpty {
                    EmptyPlaceholderView(
                        title: "No feedback yet",
                        message: "Submit a case and attendings will leave guidance here.",
                        systemImage: "bubble.left.and.exclamationmark.bubble.right"
                    )
                } else {
                    ForEach(feedbackItems, id: \.0.id) { entry in
                        FeedbackListCard(study: entry.0, feedback: entry.1)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .refreshable {
            await viewModel.preloadFeedbackForMyStudies()
        }
        .task {
            await viewModel.preloadFeedbackForMyStudies()
        }
    }
}

private struct FeedbackListCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let study: Study
    let feedback: [Feedback]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let metadata = StudyMetadata.decode(from: study.notes)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metadata.caseTitle ?? study.examType)
                        .font(.headline)
                    Text(study.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(status: study.status)
            }
            
            ForEach(feedback, id: \.id) { item in
                Divider()
                FeedbackContentCard(feedback: item)
            }
            
            Button("Open Study") {
                Task { await viewModel.loadStudyDetail(for: study) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
}

private struct FeedbackContentCard: View {
    let feedback: Feedback
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let rating = feedback.rating {
                Label("Rating \(rating)/5", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
            if let payload = ReviewFeedbackPayload.decode(from: feedback.comments) {
                if !payload.summary.isEmpty {
                    Text(payload.summary)
                        .font(.subheadline)
                }
                if !payload.detailedComments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(payload.detailedComments, id: \.self) { comment in
                            Label(comment, systemImage: "checkmark.circle")
                                .font(.caption)
                        }
                    }
                }
                if !payload.teachingPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Teaching Points")
                            .font(.caption.weight(.semibold))
                        ForEach(payload.teachingPoints, id: \.self) { point in
                            Text("• \(point)")
                                .font(.caption)
                        }
                    }
                }
            } else if let comments = feedback.comments {
                Text(comments)
                    .font(.subheadline)
            }
            Text("Updated \(feedback.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
