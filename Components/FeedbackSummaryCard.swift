import SwiftUI

struct FeedbackSummaryCard: View {
    let caseData: POCUSCase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest Feedback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(caseData.title)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer()
                if let rating = caseData.feedback?.qualityRating {
                    StarRatingView(rating: rating)
                }
            }
            
            if let summary = caseData.feedback?.summary {
                Text(summary)
                    .font(.subheadline)
            }
            
            if let points = caseData.feedback?.teachingPoints {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(points, id: \.self) { point in
                        Label(point, systemImage: "lightbulb")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let annotations = caseData.feedback?.annotations, !annotations.isEmpty {
                Divider()
                AnnotationLegend(annotations: annotations)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
}

private struct StarRatingView: View {
    let rating: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .foregroundStyle(index < rating ? .yellow : .gray)
            }
        }
    }
}

private struct AnnotationLegend: View {
    let annotations: [FeedbackAnnotation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visual Highlights")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(annotations) { annotation in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(annotation.color)
                        .frame(width: 14, height: 14)
                    VStack(alignment: .leading) {
                        Text(annotation.title)
                            .font(.subheadline.weight(.semibold))
                        Text(annotation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
