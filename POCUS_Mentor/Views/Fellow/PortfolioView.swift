import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let portfolio = viewModel.fellowPortfolio {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            summaryCard(for: portfolio)
                            moduleBreakdown(for: portfolio)
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal)
                    }
                } else {
                    ContentUnavailableView(
                        "Portfolio unavailable",
                        systemImage: "chart.bar",
                        description: Text("Sign in as a fellow to view your progress.")
                    )
                    .padding()
                }
            }
            .navigationTitle("Portfolio")
        }
    }

    private func summaryCard(for summary: AppViewModel.PortfolioSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Progress")
                .font(.title3.bold())
            Text("Approved \(summary.totalAccepted) / \(summary.totalRequired) required")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: summary.overallProgress)
                .tint(.blue)
            Text("\(Int(summary.overallProgress * 100))% complete")
                .font(.caption.bold())
                .foregroundStyle(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func moduleBreakdown(for summary: AppViewModel.PortfolioSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Modules")
                .font(.title3.bold())
            ForEach(summary.perModule, id: \.module) { progress in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress.module.rawValue)
                            .font(.headline)
                        Spacer()
                        Text("\(progress.acceptedCount)/\(progress.requiredCount)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress.progress)
                        .tint(progress.module.color)
                }
                Divider()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppViewModel())
}
