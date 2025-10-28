import SwiftUI

struct FellowDashboardView: View {
    @EnvironmentObject private var appState: AppState
    
    private var fellow: Fellow? { appState.selectedFellow }
    private var recentCases: [POCUSCase] { Array(appState.filteredCases.prefix(3)) }
    
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
                Menu {
                    ForEach(appState.fellows) { fellow in
                        Button(fellow.name) {
                            appState.selectedFellow = fellow
                        }
                    }
                } label: {
                    Label(fellow?.name ?? "Select Fellow", systemImage: "person.circle")
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text(fellow?.name ?? "Fellow")
                .font(.largeTitle.bold())
            Text("Track your progress, review annotated feedback, and keep building your ultrasound mastery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var metricsGrid: some View {
        let stats = fellow?.statistics
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Cases Submitted",
                value: "\(stats?.totalCases ?? 0)",
                trendDescription: "Pending: \(stats?.pendingCases ?? 0)",
                systemImage: "doc.on.doc",
                tint: .blue
            )
            MetricCard(
                title: "Acceptance Rate",
                value: stats != nil ? String(format: "%.0f%%", (Double(stats!.acceptedCases) / Double(max(stats!.totalCases, 1))) * 100) : "--",
                trendDescription: "Avg quality score: \(String(format: "%.1f", stats?.averageQualityScore ?? 0))",
                systemImage: "hand.thumbsup.fill",
                tint: .green
            )
            MetricCard(
                title: "Learning Themes",
                value: stats?.commonThemes.first ?? "Optimize views",
                trendDescription: "Tap into feedback to close the loop.",
                systemImage: "lightbulb.fill",
                tint: .orange
            )
            MetricCard(
                title: "Turnaround",
                value: "10.4h",
                trendDescription: "Avg attending response time this month.",
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
