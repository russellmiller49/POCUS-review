import SwiftUI

struct ReportsWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List {
            Section("Insight Reports") {
                ForEach(appState.administratorReports) { report in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(report.title)
                                .font(.headline)
                            Spacer()
                            ChartBadge(type: report.chartType)
                        }
                        Text(report.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(report.highlights, id: \.self) { highlight in
                                Label(highlight, systemImage: "sparkle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Exports") {
                Label("Download monthly summary", systemImage: "arrow.down.doc")
                Label("Share compliance package", systemImage: "square.and.arrow.up")
                Label("Generate fellow transcripts", systemImage: "doc.richtext")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reports")
    }
}

private struct ChartBadge: View {
    let type: AdministratorReportSection.ChartType
    
    var body: some View {
        switch type {
        case .bar:
            Label("Bar", systemImage: "chart.bar.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.blue)
        case .line:
            Label("Line", systemImage: "chart.line.uptrend.xyaxis")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
        case .pie:
            Label("Pie", systemImage: "chart.pie.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.orange)
        case .grid:
            Label("Grid", systemImage: "square.grid.2x2")
                .labelStyle(.iconOnly)
                .foregroundStyle(.purple)
        }
    }
}
