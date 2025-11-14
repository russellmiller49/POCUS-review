import SwiftUI

struct FellowDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    private let quickResources = ResourceLink.curatedExamples
    
    private var myStudies: [Study] {
        viewModel.myStudies.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var recentStudies: [Study] {
        Array(myStudies.prefix(3))
    }
    
    private var pendingStudies: [Study] {
        myStudies.filter { [.submitted, .reviewable, .needsRevision].contains($0.status) }
    }
    
    private var acceptedStudies: [Study] {
        myStudies.filter { [.approved, .signedOff].contains($0.status) }
    }
    
    private var acceptanceRateText: String {
        let submitted = myStudies.filter { $0.status != .draft }.count
        guard submitted > 0 else { return "--" }
        let rate = Double(acceptedStudies.count) / Double(submitted)
        return String(format: "%.0f%%", rate * 100)
    }
    
    private var acceptanceDetail: String {
        let submitted = myStudies.filter { $0.status != .draft }.count
        guard submitted > 0 else { return "Submit a study to unlock analytics." }
        return "Approved \(acceptedStudies.count) / \(submitted)"
    }
    
    private var turnaroundHours: Double? {
        let hours = myStudies.compactMap { study -> Double? in
            guard
                let submittedAt = study.submittedAt,
                let signoff = viewModel.signoffs[study.id],
                let signedAt = signoff.signedAt
            else { return nil }
            return signedAt.timeIntervalSince(submittedAt) / 3600
        }
        guard !hours.isEmpty else { return nil }
        return hours.reduce(0, +) / Double(hours.count)
    }
    
    private var highlightedFeedback: (Study, Feedback)? {
        for study in myStudies {
            if let feedback = viewModel.feedback(for: study).first {
                return (study, feedback)
            }
        }
        return nil
    }
    
    private var fellowDisplayName: String {
        if let name = viewModel.currentProfile?.fullName, !name.isEmpty {
            return name
        }
        if let email = viewModel.currentProfile?.email {
            return email
        }
        return viewModel.currentSession?.profile.email ?? "Fellow"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                metricsGrid
                recentCaseSection
                feedbackHighlightSection
                quickResourcesSection
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(fellowDisplayName)
                .font(.largeTitle.bold())
            Text("Track progress, review annotated feedback, and keep building your ultrasound mastery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Cases Submitted",
                value: "\(myStudies.filter { $0.status != .draft }.count)",
                trendDescription: "Pending: \(pendingStudies.count)",
                systemImage: "doc.on.doc",
                tint: .blue
            )
            MetricCard(
                title: "Acceptance Rate",
                value: acceptanceRateText,
                trendDescription: acceptanceDetail,
                systemImage: "hand.thumbsup.fill",
                tint: .green
            )
            MetricCard(
                title: "Pending Reviews",
                value: "\(pendingStudies.count)",
                trendDescription: pendingStudies.isEmpty ? "All caught up" : "Follow up to keep momentum.",
                systemImage: "clock.badge.exclamationmark",
                tint: .orange
            )
            MetricCard(
                title: "Turnaround",
                value: turnaroundHours.map { String(format: "%.1fh", $0) } ?? "--",
                trendDescription: turnaroundHours == nil ? "Awaiting signed cases" : "Average review time",
                systemImage: "timer",
                tint: .purple
            )
        }
    }
    
    private var recentCaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Recent Cases", subtitle: "Stay on top of your latest submissions.")
            if recentStudies.isEmpty {
                EmptyPlaceholderView(
                    title: "No cases yet",
                    message: "Use the Studies tab to create your first case.",
                    systemImage: "tray"
                )
            } else {
                ForEach(recentStudies, id: \.id) { study in
                    Button {
                        Task { await viewModel.loadStudyDetail(for: study) }
                    } label: {
                        FellowStudyCard(study: study)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var feedbackHighlightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Feedback Focus", subtitle: "Highlights from recent reviews.")
            if let item = highlightedFeedback {
                FeedbackHighlightCard(study: item.0, feedback: item.1)
            } else {
                EmptyPlaceholderView(
                    title: "No feedback yet",
                    message: "Once attendings respond you'll see insights here.",
                    systemImage: "bubble.left"
                )
            }
        }
    }

    private var quickResourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Resources", subtitle: "Guides shared by attendings.")
            ForEach(quickResources) { resource in
                VStack(alignment: .leading, spacing: 6) {
                    Text(resource.title)
                        .font(.headline)
                    Text(resource.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                )
            }
        }
    }
}

private struct FellowStudyCard: View {
    let study: Study
    private var metadata: StudyMetadata { StudyMetadata.decode(from: study.notes) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metadata.caseTitle?.isEmpty == false ? metadata.caseTitle! : study.examType)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                StatusChip(status: study.status)
            }
            Text(study.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let context = metadata.clinicalContext, !context.isEmpty {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
}

private struct FeedbackHighlightCard: View {
    let study: Study
    let feedback: Feedback
    
    var body: some View {
        let metadata = StudyMetadata.decode(from: study.notes)
        VStack(alignment: .leading, spacing: 8) {
            Text(metadata.caseTitle ?? study.examType)
                .font(.headline)
            if let payload = ReviewFeedbackPayload.decode(from: feedback.comments) {
                if !payload.summary.isEmpty {
                    Text(payload.summary)
                        .font(.subheadline)
                }
                if !payload.detailedComments.isEmpty {
                    Divider()
                    ForEach(payload.detailedComments, id: \.self) { comment in
                        Label(comment, systemImage: "checkmark.seal")
                            .font(.caption)
                    }
                }
            } else if let comments = feedback.comments {
                Text(comments)
                    .font(.subheadline)
            }
            Text("Reviewed \(feedback.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
}
