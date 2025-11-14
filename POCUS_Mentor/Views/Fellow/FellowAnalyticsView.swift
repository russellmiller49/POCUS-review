import SwiftUI

struct FellowAnalyticsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    private var stats: AppViewModel.PortfolioStats { viewModel.portfolioStats }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    title: "Learning Analytics",
                    subtitle: "Live metrics from your Supabase studies."
                )
                summaryMetrics
                examBreakdown
                statusDistribution
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var summaryMetrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Total Cases",
                value: "\(stats.totalCases)",
                trendDescription: "Across all statuses",
                systemImage: "doc.text.image",
                tint: .blue
            )
            MetricCard(
                title: "Completed",
                value: "\(stats.completed)",
                trendDescription: "Approved or signed off",
                systemImage: "checkmark.seal.fill",
                tint: .green
            )
            MetricCard(
                title: "Returned",
                value: "\(stats.returned)",
                trendDescription: stats.returned == 0 ? "Great job!" : "Needs revisions",
                systemImage: "arrow.uturn.backward",
                tint: .pink
            )
            MetricCard(
                title: "Acceptance",
                value: acceptanceRateText,
                trendDescription: "Completed / Submitted",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .purple
            )
        }
    }
    
    private var examBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Exam Mix", subtitle: "Where you're spending your time.")
            if stats.examBreakdown.isEmpty {
                EmptyPlaceholderView(
                    title: "No cases yet",
                    message: "Create a study to see distribution.",
                    systemImage: "chart.bar"
                )
            } else {
                ForEach(stats.examBreakdown) { stat in
                    HStack {
                        Text(stat.examType)
                        Spacer()
                        Text("\(stat.count)")
                            .font(.headline)
                    }
                    Divider()
                }
            }
        }
    }
    
    private var statusDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Status Distribution", subtitle: "Monitor drafts vs submitted cases.")
            VStack(alignment: .leading, spacing: 8) {
                StatusProgressRow(title: "Drafts", count: stats.drafts, total: stats.totalCases, tint: .gray)
                StatusProgressRow(title: "Submitted", count: stats.submitted, total: stats.totalCases, tint: .blue)
                StatusProgressRow(title: "Returned", count: stats.returned, total: stats.totalCases, tint: .pink)
                StatusProgressRow(title: "Completed", count: stats.completed, total: stats.totalCases, tint: .green)
            }
        }
    }
    
    private var acceptanceRateText: String {
        let submitted = stats.submitted + stats.completed + stats.returned
        guard submitted > 0 else { return "--" }
        let rate = Double(stats.completed) / Double(submitted)
        return String(format: "%.0f%%", rate * 100)
    }
}

private struct StatusProgressRow: View {
    let title: String
    let count: Int
    let total: Int
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.headline)
            }
            ProgressView(value: progress)
                .tint(tint)
        }
    }
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
}
