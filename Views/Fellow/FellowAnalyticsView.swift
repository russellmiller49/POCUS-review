import SwiftUI

struct FellowAnalyticsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Learning Analytics", subtitle: "Track your competency growth and review efficiency over time.")
                analyticsSummary
                skillTrendSection
                feedbackThemesSection
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var analyticsSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Snapshot", selection: $appState.selectedAnalyticsSnapshot.animation(.easeInOut)) {
                ForEach(SampleData.analyticsSnapshots, id: \.periodLabel) { snapshot in
                    Text(snapshot.periodLabel).tag(snapshot)
                }
            }
            .pickerStyle(.segmented)
            
            VStack(spacing: 16) {
                MetricCard(
                    title: "Cases",
                    value: "\(appState.selectedAnalyticsSnapshot.totalCases)",
                    trendDescription: "Reviewed this period",
                    systemImage: "doc.plaintext",
                    tint: .blue
                )
                MetricCard(
                    title: "Acceptance Rate",
                    value: String(format: "%.0f%%", appState.selectedAnalyticsSnapshot.acceptanceRate * 100),
                    trendDescription: "Growth vs prior period",
                    systemImage: "checkmark.seal.fill",
                    tint: .teal
                )
                MetricCard(
                    title: "Turnaround",
                    value: String(format: "%.1fh", appState.selectedAnalyticsSnapshot.averageReviewTimeHours),
                    trendDescription: "Average time to feedback",
                    systemImage: "clock.badge.checkmark",
                    tint: .purple
                )
            }
        }
    }
    
    private var skillTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Skill Trajectory", subtitle: "Normalized growth in key competency domains (0 - 1 scale).")
            ForEach(appState.selectedAnalyticsSnapshot.skillTrends) { trend in
                SkillTrendCard(trend: trend)
            }
        }
    }
    
    private var feedbackThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top Feedback Themes", subtitle: "Focus your deliberate practice on these recurring topics.")
            ForEach(appState.selectedAnalyticsSnapshot.topFeedbackThemes, id: \.self) { theme in
                Label(theme, systemImage: "list.bullet.rectangle.portrait")
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
            }
        }
    }
}

private struct SkillTrendCard: View {
    let trend: SkillTrend
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trend.skillName)
                .font(.headline)
            TrendLine(values: trend.progressValues)
                .frame(height: 100)
            HStack {
                ForEach(trend.progressValues.indices, id: \.self) { index in
                    VStack {
                        Text(String(format: "%.2f", trend.progressValues[index]))
                            .font(.caption.monospacedDigit())
                        Text("W\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }
}

private struct TrendLine: View {
    let values: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(width: geometry.size.width, height: geometry.size.height)
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            
            ForEach(points.indices, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 8, height: 8)
                    .position(points[index])
            }
        }
    }
    
    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard let minValue = values.min(),
              let maxValue = values.max(),
              maxValue - minValue > 0 else {
            return values.enumerated().map { index, value in
                let x = CGFloat(index) / CGFloat(Swift.max(values.count - 1, 1)) * width
                let y = height - CGFloat(value) * height
                return CGPoint(x: x, y: y)
            }
        }
        let xSpacing = width / CGFloat(Swift.max(values.count - 1, 1))
        return values.enumerated().map { index, value in
            let normalized = (value - minValue) / (maxValue - minValue)
            let x = CGFloat(index) * xSpacing
            let y = height - CGFloat(normalized) * height
            return CGPoint(x: x, y: y)
        }
    }
}
