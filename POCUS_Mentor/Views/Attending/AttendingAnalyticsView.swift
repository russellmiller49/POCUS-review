import SwiftUI

struct AttendingAnalyticsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    private var reviewQueue: [Study] {
        viewModel.reviewQueue
    }
    
    private var completedStudies: [Study] {
        viewModel.studies.filter { study in
            [.approved, .signedOff].contains(study.status)
        }
    }
    
    private var myFeedback: [Feedback] {
        guard let session = viewModel.currentSession else { return [] }
        return viewModel.feedbackByStudy.values.flatMap { $0 }
            .filter { $0.reviewerId == session.profile.id }
    }
    
    private var averageTurnaroundHours: Double {
        // Calculate average time from submission to signoff
        let completedWithSignoffs = completedStudies.compactMap { study -> Double? in
            guard let signoff = viewModel.signoffs[study.id],
                  let submittedAt = study.submittedAt,
                  let signedAt = signoff.signedAt else { return nil }
            return signedAt.timeIntervalSince(submittedAt) / 3600.0
        }
        guard !completedWithSignoffs.isEmpty else { return 0 }
        return completedWithSignoffs.reduce(0, +) / Double(completedWithSignoffs.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Teaching Impact", subtitle: "Monitor review efficiency and fellow progress across your assignments.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(
                        title: "Average Turnaround",
                        value: String(format: "%.1fh", averageTurnaroundHours),
                        trendDescription: "Target: < 12h",
                        systemImage: "timer",
                        tint: .purple
                    )
                    MetricCard(
                        title: "Open Queue",
                        value: "\(reviewQueue.count)",
                        trendDescription: "Cases awaiting review",
                        systemImage: "tray.full",
                        tint: .orange
                    )
                    MetricCard(
                        title: "Completed Feedback",
                        value: "\(myFeedback.count)",
                        trendDescription: "Reviews provided",
                        systemImage: "pencil.circle.fill",
                        tint: .blue
                    )
                    MetricCard(
                        title: "Approved Cases",
                        value: "\(completedStudies.count)",
                        trendDescription: "Signed off",
                        systemImage: "checkmark.seal.fill",
                        tint: .green
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Fellow Progress", subtitle: "Cases by fellow you're supervising.")
                    if viewModel.fellowDirectory.isEmpty {
                        EmptyPlaceholderView(
                            title: "No fellows",
                            message: "Fellow activity will appear here once they submit cases.",
                            systemImage: "person.3"
                        )
                    } else {
                        ForEach(viewModel.fellowDirectory) { fellow in
                            FellowProgressRow(
                                fellow: fellow,
                                studies: viewModel.studies.filter { $0.createdBy == fellow.id }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Analytics")
        .refreshable {
            await viewModel.refreshStudies()
        }
    }
}

private struct FellowProgressRow: View {
    let fellow: UserProfileSummary
    let studies: [Study]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fellow.fullName ?? fellow.email)
                    .font(.headline)
                Spacer()
                Text("\(completedCount)/\(totalCount) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: completionRate)
                .accentColor(.green)
            Text("\(submittedCount) submitted, \(returnedCount) returned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
    
    private var totalCount: Int {
        studies.count
    }
    
    private var completedCount: Int {
        studies.filter { [.approved, .signedOff].contains($0.status) }.count
    }
    
    private var submittedCount: Int {
        studies.filter { [.submitted, .reviewable].contains($0.status) }.count
    }
    
    private var returnedCount: Int {
        studies.filter { $0.status == .needsRevision }.count
    }
    
    private var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}
