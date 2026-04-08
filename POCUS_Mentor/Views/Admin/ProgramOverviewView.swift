import SwiftUI

struct ProgramOverviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    
    private var analytics: AppViewModel.ProgramAnalytics {
        viewModel.programAnalytics
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Program Pulse", subtitle: "Live snapshot of fellow throughput.")
                metricsGrid
                examBreakdown
                fellowSummaries
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Program Overview")
        .refreshable {
            await viewModel.refreshStudies()
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Total Cases",
                value: "\(analytics.totalCases)",
                trendDescription: "Across this institution",
                systemImage: "doc.on.doc",
                tint: .blue
            )
            MetricCard(
                title: "Submitted",
                value: "\(analytics.submitted)",
                trendDescription: "Awaiting review",
                systemImage: "clock.badge.exclamationmark",
                tint: .orange
            )
            MetricCard(
                title: "Returned",
                value: "\(analytics.returned)",
                trendDescription: "Need revisions",
                systemImage: "arrow.uturn.backward",
                tint: .pink
            )
            MetricCard(
                title: "Acceptance",
                value: acceptanceRateText,
                trendDescription: "Completed / Submitted",
                systemImage: "checkmark.seal.fill",
                tint: .green
            )
        }
    }
    
    private var examBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Exam Distribution", subtitle: "Identify modality demand.")
            if analytics.examBreakdown.isEmpty {
                EmptyPlaceholderView(
                    title: "No cases",
                    message: "Once studies are logged you'll see the mix here.",
                    systemImage: "chart.bar"
                )
            } else {
                ForEach(analytics.examBreakdown) { stat in
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
    
    private var fellowSummaries: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Fellow Activity", subtitle: "Monitor queues by learner.")
            if analytics.fellowSummaries.isEmpty {
                EmptyPlaceholderView(
                    title: "No fellows yet",
                    message: "Invite learners to your institution to track progress.",
                    systemImage: "person.3"
                )
            } else {
                ForEach(analytics.fellowSummaries) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.name)
                            .font(.headline)
                        Text(summary.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            LabeledValue(title: "Drafts", value: "\(summary.drafts)")
                            Spacer()
                            LabeledValue(title: "Submitted", value: "\(summary.submitted)")
                            Spacer()
                            LabeledValue(title: "Returned", value: "\(summary.returned)")
                            Spacer()
                            LabeledValue(title: "Completed", value: "\(summary.completed)")
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
        }
    }
    
    private var acceptanceRateText: String {
        let submitted = analytics.submitted + analytics.returned + analytics.completed
        guard submitted > 0 else { return "--" }
        let rate = Double(analytics.completed) / Double(submitted)
        return String(format: "%.0f%%", rate * 100)
    }
}

private struct LabeledValue: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}
