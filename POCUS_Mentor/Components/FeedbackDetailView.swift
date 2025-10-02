import SwiftUI

struct FeedbackDetailView: View {
    let feedback: CaseFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Annotations
            if !feedback.annotations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Annotations", subtitle: "Visual feedback on your images and videos.")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(feedback.annotations) { annotation in
                                AnnotationCard(annotation: annotation)
                            }
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Detailed Comments", subtitle: "What your attending saw and recommended.")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(feedback.detailedComments, id: \.self) { comment in
                        Label(comment, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }

                SectionHeader(title: "Teaching Points")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(feedback.teachingPoints, id: \.self) { point in
                        Label(point, systemImage: "lightbulb")
                            .font(.subheadline)
                    }
                }

                if !feedback.recommendedResources.isEmpty {
                    SectionHeader(title: "Suggested Resources")
                    ForEach(feedback.recommendedResources, id: \.self) { url in
                        Link(destination: url) {
                            Label(url.absoluteString, systemImage: "link")
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
            )
        }
    }
}

struct AnnotationCard: View {
    let annotation: FeedbackAnnotation
    @State private var showFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Annotated image
            if let imageData = annotation.annotatedImage,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        showFullScreen = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    )
            }

            // Annotation info
            HStack(spacing: 8) {
                Circle()
                    .fill(annotation.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(annotation.title)
                        .font(.subheadline.bold())

                    if !annotation.description.isEmpty {
                        Text(annotation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let timestamp = annotation.timestamp {
                        Text("@ \(formatTimestamp(timestamp))")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .frame(width: 200, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .fullScreenCover(isPresented: $showFullScreen) {
            if let imageData = annotation.annotatedImage,
               let uiImage = UIImage(data: imageData) {
                NavigationStack {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .navigationTitle(annotation.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showFullScreen = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
