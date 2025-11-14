import SwiftUI
import AVKit

struct ReviewDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let study: Study

    @State private var rating: Int = 3
    @State private var comments: String = ""
    @State private var signoffStatus: SignoffStatus = .approved
    @State private var annotations: [FeedbackAnnotation] = []
    @State private var mediaComments: [UUID: String] = [:]
    @State private var detail: AppViewModel.StudyDetailState?

    var body: some View {
        NavigationStack {
            Form {
                if let detail {
                    CaseOverviewSection(
                        detail: detail,
                        fellow: viewModel.fellowInfo(for: study.createdBy)
                    )
                    ClinicalDetailsSection(detail: detail)
                    MediaSection(
                        detail: detail,
                        annotations: $annotations,
                        mediaComments: $mediaComments
                    ) { media, text in
                        saveComment(text, for: media)
                    }
                } else {
                    Section {
                        ProgressView("Loading case details…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section("Assessment") {
                    Stepper(value: $rating, in: 1...5) {
                        Label("Rating \(rating)/5", systemImage: "star.fill")
                    }
                    TextEditor(text: $comments)
                        .frame(height: 120)
                }

                Section("Sign-off") {
                    Picker("Status", selection: $signoffStatus) {
                        Text("Approve").tag(SignoffStatus.approved)
                        Text("Needs Revision").tag(SignoffStatus.revisions)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submitReview(
                                for: study,
                                rating: rating,
                                summary: comments,
                                detailedComments: [],
                                teachingPoints: [],
                                annotations: annotationPayloads(for: detail),
                                signoffStatus: signoffStatus
                            )
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .task {
            detail = await viewModel.fetchStudyDetail(for: study)
        }
    }

    private func annotationPayloads(for detail: AppViewModel.StudyDetailState?) -> [ReviewAnnotationPayload] {
        guard let detail else { return [] }
        let namesById = Dictionary(uniqueKeysWithValues: detail.media.map { media in
            (media.id, media.displayName)
        })
        return annotations.compactMap { annotation in
            let mediaName = annotation.mediaID.flatMap { namesById[$0] }
            return annotation.toPayload(mediaName: mediaName)
        }
    }

    private func saveComment(_ text: String, for media: Media) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            await viewModel.addMediaComment(for: media, comment: trimmed)
            await MainActor.run {
                mediaComments[media.id] = ""
            }
            detail = await viewModel.fetchStudyDetail(for: study)
        }
    }
}

private struct CaseOverviewSection: View {
    let detail: AppViewModel.StudyDetailState
    let fellow: (name: String, email: String)?

    var body: some View {
        let metadata = detail.metadata
        Section("Case Overview") {
            Text(metadata.caseTitle ?? detail.study.examType)
                .font(.headline)
            if let module = metadata.module {
                Label(module.rawValue, systemImage: "waveform.path.ecg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let fellow {
                Text("Fellow: \(fellow.name)")
                    .font(.subheadline)
            }
            if let submitted = detail.study.submittedAt {
                Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ClinicalDetailsSection: View {
    let detail: AppViewModel.StudyDetailState

    var body: some View {
        let metadata = detail.metadata

        Section("Patient & Clinical Context") {
            if let age = metadata.patientAge {
                Text("Age: \(age) years")
            }
            if let gender = metadata.patientGender, !gender.isEmpty {
                Text("Gender: \(gender)")
            }
            if let context = metadata.clinicalContext, !context.isEmpty {
                Text(context)
                    .font(.body)
            } else {
                Text("No clinical context provided.")
                    .foregroundStyle(.secondary)
            }
            if let findings = metadata.preliminaryFindings, !findings.isEmpty {
                Divider()
                Text("Preliminary Interpretation")
                    .font(.subheadline.weight(.semibold))
                Text(findings)
            }
            if let measurements = metadata.measurements, !measurements.isEmpty {
                Divider()
                Text("Measurements")
                    .font(.subheadline.weight(.semibold))
                ForEach(measurements) { measure in
                    HStack {
                        Text(measure.label.isEmpty ? "Value" : measure.label)
                        Spacer()
                        Text(measure.value)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct MediaSection: View {
    let detail: AppViewModel.StudyDetailState
    @Binding var annotations: [FeedbackAnnotation]
    @Binding var mediaComments: [UUID: String]
    let saveComment: (Media, String) -> Void

    var body: some View {
        Section("Media") {
            if detail.media.isEmpty {
                Text("No media attached.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detail.media, id: \.id) { media in
                    let label = detail.metadata.mediaLabel(for: media.id)
                    MediaAttachmentRow(
                        media: media,
                        annotations: $annotations,
                        commentText: Binding(
                            get: { mediaComments[media.id] ?? "" },
                            set: { mediaComments[media.id] = $0 }
                        ),
                        existingFeedback: detail.feedback.filter { $0.mediaId == media.id },
                        onSaveComment: saveComment,
                        label: label
                    )
                }
            }
        }
    }
}

private struct MediaAttachmentRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let media: Media
    @Binding var annotations: [FeedbackAnnotation]
    @Binding var commentText: String
    let existingFeedback: [Feedback]
    let onSaveComment: (Media, String) -> Void
    let label: String?
    @State private var signedURL: URL?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showFullScreen = false
    @State private var showAnnotator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
            if !existingAnnotations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(existingAnnotations) { annotation in
                            ReviewAnnotationChip(annotation: annotation) {
                                annotations.removeAll { $0.id == annotation.id }
                            }
                        }
                    }
                }
            }
            if !existingFeedback.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(existingFeedback, id: \.id) { feedback in
                        MediaFeedbackRow(feedback: feedback)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add comment", text: $commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Save Comment") {
                    onSaveComment(media, commentText)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .task {
            await loadSignedURLIfNeeded()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let url = signedURL {
                FullScreenMediaViewer(url: url, media: media)
            }
        }
        .sheet(isPresented: $showAnnotator) {
            if let url = signedURL {
                ReviewMediaAnnotationView(
                    media: media,
                    signedURL: url,
                    annotations: $annotations
                )
            }
        }
    }

    private var displayName: String {
        if let label, !label.isEmpty { return label }
        return media.displayName
    }

    private var existingAnnotations: [FeedbackAnnotation] {
        annotations.filter { $0.mediaID == media.id }
    }

    private var header: some View {
        HStack {
            Image(systemName: isVideo ? "video.fill" : (isImage ? "photo" : "doc"))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if label != nil {
                    Text(media.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Text(media.contentType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isVideo, signedURL != nil {
                Button {
                    showFullScreen = true
                } label: {
                    Label("Play", systemImage: "play.circle.fill")
                }
                .labelStyle(.iconOnly)
            }
            if (isVideo || isImage), signedURL != nil {
                Button {
                    showAnnotator = true
                } label: {
                    Image(systemName: "pencil.tip.crop.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Annotate media")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let error = loadError {
            Text(error)
                .foregroundStyle(.secondary)
        } else if let url = signedURL {
            if isImage {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    case .failure:
                        Text("Unable to load image.")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if isVideo {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Text("Unsupported media type.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isImage: Bool {
        media.contentType.lowercased().hasPrefix("image/")
    }

    private var isVideo: Bool {
        media.contentType.lowercased().hasPrefix("video/")
    }

    private func loadSignedURLIfNeeded() async {
        guard signedURL == nil else {
            isLoading = false
            return
        }
        isLoading = true
        if let url = await viewModel.signedURL(for: media) {
            signedURL = url
            loadError = nil
        } else {
            loadError = "Unable to load media."
        }
        isLoading = false
    }
}

private struct ReviewAnnotationChip: View {
    let annotation: FeedbackAnnotation
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(annotation.title)
                .font(.caption)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemBackground)))
    }
}

private struct MediaFeedbackRow: View {
    let feedback: Feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(feedback.comments ?? "No comment")
            Text(feedback.createdAt, format: .dateTime.month().day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
    }
}

private struct FullScreenMediaViewer: View {
    let url: URL
    let media: Media
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            Group {
                if media.contentType.lowercased().hasPrefix("image/") {
                    Color.black.ignoresSafeArea()
                        .overlay(
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().tint(.white)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Text("Unable to load image.")
                                        .foregroundStyle(.white)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding()
                        )
                } else if media.contentType.lowercased().hasPrefix("video/") {
                    VideoPlayer(player: player)
                        .onAppear {
                            if player == nil {
                                player = AVPlayer(url: url)
                            }
                            player?.play()
                        }
                        .onDisappear {
                            player?.pause()
                        }
                } else {
                    Text("Unsupported media type.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(media.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

extension Media {
    var displayName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }

    var isImage: Bool {
        contentType.lowercased().hasPrefix("image/")
    }

    var isVideo: Bool {
        contentType.lowercased().hasPrefix("video/")
    }
}
