import SwiftUI

struct AttendingAnalyticsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Teaching Impact", subtitle: "Monitor review efficiency and fellow progress across your assignments.")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(
                        title: "Average Turnaround",
                        value: String(format: "%.1fh", appState.selectedAttending?.averageTurnaroundHours ?? 0),
                        trendDescription: "Target: < 12h",
                        systemImage: "timer",
                        tint: .purple
                    )
                    MetricCard(
                        title: "Open Queue",
                        value: "\(appState.reviewQueue.count)",
                        trendDescription: "Cases awaiting review",
                        systemImage: "tray.full",
                        tint: .orange
                    )
                    MetricCard(
                        title: "Completed Feedback",
                        value: "\(appState.completedReviews.count)",
                        trendDescription: "Annotated this month",
                        systemImage: "pencil.circle.fill",
                        tint: .blue
                    )
                    MetricCard(
                        title: "Fellow Satisfaction",
                        value: "4.6★",
                        trendDescription: "Based on last 20 reviews",
                        systemImage: "hand.thumbsup",
                        tint: .green
                    )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Feedback Themes", subtitle: "Top coaching topics you've emphasized recently.")
                    ForEach(appState.selectedAnalyticsSnapshot.topFeedbackThemes, id: \.self) { theme in
                        Label(theme, systemImage: "quote.bubble")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemBackground)))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Fellow Progress Spotlight", subtitle: "Acceptance trend for fellows you supervise.")
                    ForEach(appState.fellows) { fellow in
                        FellowProgressRow(fellow: fellow, cases: appState.cases.filter { $0.fellow.id == fellow.id })
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

private struct FellowProgressRow: View {
    let fellow: Fellow
    let cases: [POCUSCase]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fellow.name)
                    .font(.headline)
                Spacer()
                Text("\(acceptedCount)/\(cases.count) accepted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: acceptanceRate)
                .accentColor(.green)
            Text("Common themes: \(fellow.statistics.commonThemes.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }
    
    private var acceptedCount: Int {
        cases.filter { $0.feedback?.status == .accepted }.count
    }
    
    private var acceptanceRate: Double {
        guard !cases.isEmpty else { return 0 }
        return Double(acceptedCount) / Double(cases.count)
    }
}
