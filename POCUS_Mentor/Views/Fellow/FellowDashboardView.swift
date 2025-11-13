import SwiftUI

struct FellowDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: AppViewModel
    
    private var fellow: Fellow? { appState.selectedFellow }
    private var recentCases: [POCUSCase] { Array(appState.filteredCases.prefix(3)) }
    private var fellowDisplayName: String {
        if let name = viewModel.currentProfile?.fullName, !name.isEmpty {
            return name
        }
        if let email = viewModel.currentProfile?.email {
            return email
        }
        return fellow?.name ?? viewModel.currentSession?.profile.email ?? "Fellow"
    }
    private var submittedStudies: [Study] {
        guard let userId = viewModel.currentSession?.profile.id else { return [] }
        return viewModel.studies.filter { $0.createdBy == userId && $0.status != .draft }
    }
    private var submittedStudyCount: Int { submittedStudies.count }
    private var pendingStudyCount: Int {
        submittedStudies.filter { [.submitted, .reviewable, .needsRevision].contains($0.status) }.count
    }
    private var acceptedStudyCount: Int {
        submittedStudies.filter { [.approved, .signedOff].contains($0.status) }.count
    }
    private var acceptanceRateText: String {
        guard submittedStudyCount > 0 else { return "--" }
        let rate = Double(acceptedStudyCount) / Double(submittedStudyCount)
        return String(format: "%.0f%%", rate * 100)
    }
    private var acceptanceRateDetail: String {
        guard submittedStudyCount > 0 else { return "Submit a study to unlock analytics." }
        return "Approved \(acceptedStudyCount) / \(submittedStudyCount)"
    }
    private var turnaroundDurations: [Double] {
        submittedStudies.compactMap { study in
            guard
                let submittedAt = study.submittedAt,
                let signoff = viewModel.signoffs[study.id],
                let signedAt = signoff.signedAt
            else { return nil }
            return signedAt.timeIntervalSince(submittedAt) / 3600
        }
    }
    private var turnaroundText: String {
        guard let average = averageTurnaroundHours else { return "--" }
        return String(format: "%.1fh", average)
    }
    private var turnaroundDetail: String {
        if turnaroundDurations.isEmpty {
            return submittedStudyCount == 0 ? "Submit a study to track review time." : "Awaiting completed reviews."
        }
        return "Based on \(turnaroundDurations.count) signed cases."
    }
    private var averageTurnaroundHours: Double? {
        guard !turnaroundDurations.isEmpty else { return nil }
        return turnaroundDurations.reduce(0, +) / Double(turnaroundDurations.count)
    }
    private var learningHighlightTitle: String {
        if pendingStudyCount > 0 {
            return "Follow up on pending cases"
        }
        if acceptedStudyCount > 0 {
            return "Review accepted feedback"
        }
        return "Upload your first case"
    }
    private var learningHighlightSubtitle: String {
        if pendingStudyCount > 0 {
            return "\(pendingStudyCount) case\(pendingStudyCount == 1 ? "" : "s") awaiting review."
        }
        if acceptedStudyCount > 0 {
            return "Great job—keep the momentum going."
        }
        return "Submit a case to unlock personalized insights."
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                metricsGrid
                recentCaseSection
                feedbackHighlightSection
                resourcesSection
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label(fellowDisplayName, systemImage: "person.circle")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(fellowDisplayName)
                .font(.largeTitle.bold())
            Text("Track your progress, review annotated feedback, and keep building your ultrasound mastery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var metricsGrid: some View {
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Cases Submitted",
                value: "\(submittedStudyCount)",
                trendDescription: "Pending: \(pendingStudyCount)",
                systemImage: "doc.on.doc",
                tint: .blue
            )
            MetricCard(
                title: "Acceptance Rate",
                value: acceptanceRateText,
                trendDescription: acceptanceRateDetail,
                systemImage: "hand.thumbsup.fill",
                tint: .green
            )
            MetricCard(
                title: "Learning Focus",
                value: learningHighlightTitle,
                trendDescription: learningHighlightSubtitle,
                systemImage: "lightbulb.fill",
                tint: .orange
            )
            MetricCard(
                title: "Turnaround",
                value: turnaroundText,
                trendDescription: turnaroundDetail,
                systemImage: "clock.arrow.circlepath",
                tint: .purple
            )
        }
    }
    
    private var recentCaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Recent Cases", subtitle: "Stay on top of pending feedback and submissions.")
            ForEach(recentCases) { caseData in
                NavigationLink {
                    CaseDetailView(caseData: caseData)
                } label: {
                    CaseCardView(caseData: caseData, showFellowDetails: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var feedbackHighlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Feedback Focus", subtitle: "Themes pulled from recent attending reviews.")
            if let caseWithFeedback = appState.filteredCases.first(where: { $0.feedback != nil }) {
                FeedbackSummaryCard(caseData: caseWithFeedback)
            } else {
                EmptyPlaceholderView(title: "No feedback yet", message: "Once attendings respond you'll see annotated highlights here.", systemImage: "bubble.left")
            }
        }
    }
    
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Quick Resources", subtitle: "Guidelines and checklists suggested by mentors.")
            ForEach(appState.resourceLinks) { resource in
                ResourceRow(resource: resource)
            }
        }
    }
}

private struct ResourceRow: View {
    let resource: ResourceLink
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(resource.title)
                .font(.headline)
            Text(resource.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }
}
