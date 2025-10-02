import SwiftUI

struct ComplianceCenterView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Compliance Command", subtitle: "Stay audit-ready with security controls and training checkpoints.")
                securityHighlights
                auditLogPreview
                trainingStatus
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Compliance")
    }
    
    private var securityHighlights: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Security Highlights")
            ComplianceCard(systemImage: "lock.fill", title: "HIPAA compliant", message: "End-to-end encryption with daily key rotation.")
            ComplianceCard(systemImage: "faceid", title: "Role-based access", message: "Fellows, attendings, and administrators only see data scoped to their permissions.")
            ComplianceCard(systemImage: "shield.checkerboard", title: "Audit trails", message: "Every annotation, review, and export is logged for accountability.")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var auditLogPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Audit Events", subtitle: "Export full logs during accreditation reviews.")
            ForEach(sampleEvents, id: \.self) { event in
                Label(event, systemImage: "list.bullet.rectangle")
                    .font(.caption)
            }
            Button("Export audit log") {}
                .buttonStyle(.bordered)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var trainingStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Training Completion", subtitle: "Track required annual certifications for all users.")
            ForEach(appState.fellows) { fellow in
                HStack {
                    Text(fellow.name)
                    Spacer()
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            Divider()
            Label("2 attendings due for refresher course", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
    
    private var sampleEvents: [String] {
        [
            "Dr. Sanders exported fellow progress report (2h ago)",
            "New case upload by Dr. Grant (5h ago)",
            "Administrator updated permission matrix (1d ago)"
        ]
    }
}

private struct ComplianceCard: View {
    let systemImage: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
