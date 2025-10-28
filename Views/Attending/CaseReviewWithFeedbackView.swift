import SwiftUI
import AVKit

struct CaseReviewWithFeedbackView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let caseData: POCUSCase

    @State private var selectedMedia: CaseMedia?
    @State private var showAnnotationTool = false
    @State private var qualityRating: Int = 3
    @State private var feedbackSummary: String = ""
    @State private var detailedComments: [String] = []
    @State private var newComment: String = ""
    @State private var annotations: [FeedbackAnnotation] = []
    @State private var teachingPoints: [String] = []
    @State private var newTeachingPoint: String = ""
    @State private var feedbackStatus: FeedbackStatus = .accepted

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // Landscape: Side-by-side layout
                    HStack(spacing: 0) {
                        // Left: Case Review Panel
                        caseReviewPanel
                            .frame(width: geometry.size.width * 0.6)

                        Divider()

                        // Right: Feedback Panel
                        feedbackPanel
                            .frame(width: geometry.size.width * 0.4)
                    }
                } else {
                    // Portrait: Stacked layout
                    VStack(spacing: 0) {
                        caseReviewPanel
                            .frame(height: geometry.size.height * 0.5)

                        Divider()

                        feedbackPanel
                            .frame(height: geometry.size.height * 0.5)
                    }
                }
            }
            .navigationTitle(caseData.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Submit Feedback") {
                        submitFeedback()
                    }
                    .disabled(!canSubmitFeedback)
                }
            }
            .sheet(item: $selectedMedia) { media in
                MediaAnnotationView(
                    media: media,
                    annotations: $annotations
                )
            }
        }
    }

    private var caseReviewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Case Overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Case Overview")
                        .font(.headline)

                    LabeledContent("Fellow", value: caseData.fellow.name)
                    LabeledContent("Age", value: "\(caseData.patientAge)")
                    LabeledContent("Gender", value: caseData.patientGender)
                    LabeledContent("Clinical Context", value: caseData.clinicalIndication)

                    if !caseData.preliminaryFindings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preliminary Findings")
                                .font(.subheadline.bold())
                            Text(caseData.preliminaryFindings)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))

                // Measurements
                if !caseData.measurements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Measurements")
                            .font(.headline)

                        ForEach(caseData.measurements) { measurement in
                            LabeledContent(measurement.label, value: measurement.value)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
                }

                // Media organized by echo view
                mediaByEchoViewSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var mediaByEchoViewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Echo Views & Media")
                .font(.headline)

            ForEach(EchoView.groupedByCategory, id: \.category) { group in
                let mediaInCategory = caseData.media.filter { media in
                    guard let echoView = media.echoView else { return false }
                    return echoView.category == group.category
                }

                if !mediaInCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.category)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        ForEach(mediaInCategory) { media in
                            MediaReviewCard(
                                media: media,
                                annotations: annotations.filter { $0.mediaID == media.id }
                            ) {
                                selectedMedia = media
                            }
                        }
                    }
                }
            }

            // Media without echo view assignment
            let unassignedMedia = caseData.media.filter { $0.echoView == nil }
            if !unassignedMedia.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Other Media")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    ForEach(unassignedMedia) { media in
                        MediaReviewCard(
                            media: media,
                            annotations: annotations.filter { $0.mediaID == media.id }
                        ) {
                            selectedMedia = media
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }

    private var feedbackPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Decision")
                        .font(.headline)

                    Picker("Status", selection: $feedbackStatus) {
                        Text("Accept").tag(FeedbackStatus.accepted)
                        Text("Request Revisions").tag(FeedbackStatus.revisionsRequested)
                        Text("Reject").tag(FeedbackStatus.rejected)
                    }
                    .pickerStyle(.segmented)
                }

                // Quality Rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality Rating")
                        .font(.headline)

                    HStack {
                        ForEach(1...5, id: \.self) { rating in
                            Image(systemName: rating <= qualityRating ? "star.fill" : "star")
                                .foregroundStyle(rating <= qualityRating ? .yellow : .gray)
                                .onTapGesture {
                                    qualityRating = rating
                                }
                        }
                    }
                    .font(.title2)
                }

                Divider()

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)

                    TextEditor(text: $feedbackSummary)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Detailed Comments
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detailed Comments")
                        .font(.headline)

                    ForEach(detailedComments.indices, id: \.self) { index in
                        HStack {
                            Text("• \(detailedComments[index])")
                                .font(.subheadline)
                            Spacer()
                            Button(action: { detailedComments.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    HStack {
                        TextField("Add comment", text: $newComment)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newComment.isEmpty {
                                detailedComments.append(newComment)
                                newComment = ""
                            }
                        }
                    }
                }

                Divider()

                // Teaching Points
                VStack(alignment: .leading, spacing: 8) {
                    Text("Teaching Points")
                        .font(.headline)

                    ForEach(teachingPoints.indices, id: \.self) { index in
                        HStack {
                            Text("💡 \(teachingPoints[index])")
                                .font(.subheadline)
                            Spacer()
                            Button(action: { teachingPoints.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    HStack {
                        TextField("Add teaching point", text: $newTeachingPoint)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newTeachingPoint.isEmpty {
                                teachingPoints.append(newTeachingPoint)
                                newTeachingPoint = ""
                            }
                        }
                    }
                }

                // Annotations Summary
                if !annotations.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Annotations (\(annotations.count))")
                            .font(.headline)

                        ForEach(annotations) { annotation in
                            HStack {
                                Circle()
                                    .fill(annotation.color)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(annotation.title)
                                        .font(.subheadline.bold())
                                    if let mediaID = annotation.mediaID,
                                       let media = caseData.media.first(where: { $0.id == mediaID }) {
                                        Text(media.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var canSubmitFeedback: Bool {
        let hasSummary = !feedbackSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasComments = detailedComments.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasTeachingPoints = teachingPoints.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasAnnotations = !annotations.isEmpty
        return hasSummary || hasComments || hasTeachingPoints || hasAnnotations
    }

    private func submitFeedback() {
        guard let attending = appState.selectedAttending else { return }

        let cleanedSummary = feedbackSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredComments = detailedComments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let filteredTeachingPoints = teachingPoints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let feedback = CaseFeedback(
            id: UUID(),
            attending: attending,
            status: feedbackStatus,
            qualityRating: qualityRating,
            summary: cleanedSummary.isEmpty ? (filteredComments.first ?? "Feedback Submitted") : cleanedSummary,
            detailedComments: filteredComments,
            annotations: annotations,
            teachingPoints: filteredTeachingPoints,
            recommendedResources: [],
            createdAt: Date()
        )

        let newStatus: CaseStatus = feedbackStatus == .accepted ? .accepted : .needsRevision
        appState.applyFeedback(feedback, to: caseData.id, newStatus: newStatus)

        dismiss()
    }
}

struct MediaReviewCard: View {
    let media: CaseMedia
    let annotations: [FeedbackAnnotation]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack(alignment: .topTrailing) {
                    if media.type == .video, let url = media.fileURL {
                        VideoPlayerView(url: url)
                            .frame(width: 120, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 80)
                            .overlay(
                                Image(systemName: media.type == .image ? "photo" : "video.fill")
                                    .foregroundStyle(.secondary)
                            )
                    }

                    if !annotations.isEmpty {
                        Circle()
                            .fill(.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(annotations.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 5, y: -5)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let echoView = media.echoView {
                        Text(echoView.shortName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Text(media.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if !media.description.isEmpty {
                        Text(media.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "pencil.tip.crop.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ZStack {
                    Color.black
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
