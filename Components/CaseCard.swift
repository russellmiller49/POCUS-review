import SwiftUI

struct CaseCardView: View {
    let caseData: POCUSCase
    var showFellowDetails: Bool = false
    var showAttendingDetails: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(caseData.studyType)
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(caseData.urgency.color.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Text(caseData.status.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(caseData.status.badgeColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Text(caseData.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            Text(caseData.clinicalIndication)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            if showFellowDetails {
                LabeledContent("Fellow") {
                    Text(caseData.fellow.name)
                }
            }
            if showAttendingDetails {
                LabeledContent("Assigned") {
                    Text(caseData.assignedAttending.name)
                }
            }
            
            HStack {
                Label("Submitted \(submittedAgo)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TagListView(tags: caseData.tags)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
    
    private var submittedAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: caseData.submittedAt, relativeTo: Date())
    }
}
