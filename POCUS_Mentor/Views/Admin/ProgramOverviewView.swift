import SwiftUI

struct ProgramOverviewView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Program Pulse", subtitle: "Real-time snapshot of fellow engagement and teaching throughput.")
                metricsGrid
                workloadSection
                pendingTasksSection
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Program Overview")
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(appState.programMetrics) { metric in
                MetricCard(
                    title: metric.title,
                    value: metric.value,
                    trendDescription: metric.changeDescription,
                    systemImage: metric.iconName,
                    tint: metric.accentColor
                )
            }
        }
    }
    
    private var workloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Workload Distribution", subtitle: "Track pending reviews by urgency to optimize staffing.")
            ForEach(CaseUrgency.allCases) { urgency in
                let count = appState.awaitingFeedback.filter { $0.urgency == urgency }.count
                HStack {
                    Text(urgency.displayName)
                        .font(.subheadline)
                    Spacer()
                    ProgressView(value: Double(count), total: Double(max(appState.awaitingFeedback.count, 1)))
                        .accentColor(urgency.color)
                        .frame(width: 180)
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var pendingTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Action Items", subtitle: "Keep the educational program running smoothly.")
            PendingTaskRow(systemImage: "person.2.badge.gearshape", title: "Assign mentors", message: "2 fellows are missing attending assignments this cycle.")
            PendingTaskRow(systemImage: "doc.badge.gearshape", title: "Accreditation report", message: "June metrics report due in 5 days.")
            PendingTaskRow(systemImage: "lock.shield", title: "Security review", message: "Confirm HIPAA audit acknowledgements.")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
}

private struct PendingTaskRow: View {
    let systemImage: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
