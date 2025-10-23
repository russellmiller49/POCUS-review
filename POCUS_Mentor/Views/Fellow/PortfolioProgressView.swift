import SwiftUI

struct PortfolioProgressView: View {
    let fellow: Fellow

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Overall Progress
            VStack(alignment: .leading, spacing: 12) {
                Text("Portfolio Progress")
                    .font(.title2.bold())

                HStack {
                    ProgressView(value: fellow.totalPortfolioProgress)
                        .tint(.blue)
                    Text("\(Int(fellow.totalPortfolioProgress * 100))%")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                Text("\(totalAccepted) of \(totalRequired) images accepted")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )

            // Module Breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Module Progress")
                    .font(.headline)

                ForEach(fellow.portfolioProgress, id: \.module) { progress in
                    ModuleProgressCard(progress: progress)
                }
            }
        }
        .padding()
    }

    private var totalAccepted: Int {
        fellow.portfolioProgress.reduce(0) { $0 + $1.acceptedCount }
    }

    private var totalRequired: Int {
        fellow.portfolioProgress.reduce(0) { $0 + $1.requiredCount }
    }
}

struct ModuleProgressCard: View {
    let progress: PortfolioProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(progress.module.color)
                    .frame(width: 12, height: 12)

                Text(progress.module.rawValue)
                    .font(.subheadline.bold())

                Spacer()

                if progress.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(progress.acceptedCount)/\(progress.requiredCount)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            ProgressView(value: progress.progress)
                .tint(statusColor)

            Text(progress.module.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var statusColor: Color {
        if progress.isComplete { return .green }
        if progress.progress >= 0.5 { return .orange }
        return .red
    }
}

#Preview {
    PortfolioProgressView(fellow: SampleData.fellows.first!)
}
