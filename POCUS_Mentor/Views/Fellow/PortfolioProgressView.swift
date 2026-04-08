import SwiftUI

struct PortfolioProgressView: View {
    let stats: AppViewModel.PortfolioStats
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                examBreakdown
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Portfolio")
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.title2.bold())
            
            HStack {
                ProgressView(value: completionRate)
                    .tint(.blue)
                Text("\(Int(completionRate * 100))%")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    LabeledValue(title: "Drafts", value: "\(stats.drafts)")
                    LabeledValue(title: "Submitted", value: "\(stats.submitted)")
                }
                GridRow {
                    LabeledValue(title: "Returned", value: "\(stats.returned)")
                    LabeledValue(title: "Completed", value: "\(stats.completed)")
                }
                GridRow {
                    LabeledValue(title: "Acceptance", value: acceptanceRateText)
                    LabeledValue(title: "Total", value: "\(stats.totalCases)")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
    
    private var examBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exam Type Distribution")
                .font(.headline)
            if stats.examBreakdown.isEmpty {
                EmptyPlaceholderView(
                    title: "No cases logged",
                    message: "Once you submit studies you'll see the modality split here.",
                    systemImage: "chart.pie"
                )
            } else {
                ForEach(stats.examBreakdown) { stat in
                    HStack {
                        Text(stat.examType)
                            .font(.subheadline)
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        )
    }
    
    private var completionRate: Double {
        guard stats.totalCases > 0 else { return 0 }
        return Double(stats.completed) / Double(stats.totalCases)
    }
    
    private var acceptanceRateText: String {
        let submitted = stats.submitted + stats.completed + stats.returned
        guard submitted > 0 else { return "--" }
        let rate = Double(stats.completed) / Double(submitted)
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
