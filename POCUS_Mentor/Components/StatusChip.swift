import SwiftUI

struct StatusChip: View {
    let status: StudyStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(status.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(status.backgroundColor.opacity(0.15))
            )
    }
}

extension StudyStatus {
    var displayName: String {
        switch self {
        case .draft:
            return "Draft"
        case .submitted:
            return "Submitted"
        case .reviewable:
            return "Reviewable"
        case .needsRevision:
            return "Needs Revision"
        case .approved:
            return "Approved"
        case .signedOff:
            return "Signed Off"
        }
    }
    
    var textColor: Color {
        switch self {
        case .draft:
            return .secondary
        case .submitted:
            return .orange
        case .reviewable:
            return .blue
        case .needsRevision:
            return .red
        case .approved:
            return .green
        case .signedOff:
            return .purple
        }
    }
    
    var backgroundColor: Color {
        textColor
    }
}




