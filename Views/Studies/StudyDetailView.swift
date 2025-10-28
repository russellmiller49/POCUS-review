import SwiftUI
import UniformTypeIdentifiers

struct StudyDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let detail: AppViewModel.StudyDetailState

    @State private var notes: String
    @State private var showImporter = false
    @AppStorage("pocus.deidentificationAcknowledged") private var deidentificationAcknowledged: Bool = false

    init(detail: AppViewModel.StudyDetailState) {
        self.detail = detail
        _notes = State(initialValue: detail.study.notes ?? "")
    }

    private var activeUploads: [(TUSUploadService.UploadContext, TUSUploadService.UploadStatus)] {
        viewModel.uploads(for: detail.study.id)
    }

    private var uploadItems: [UploadDisplay] {
        activeUploads.map { UploadDisplay(context: $0.0, status: $0.1) }
    }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(detail.study.examType)
                .toolbar {
                    if viewModel.canSubmitStudy {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Submit") {
                                Task { await viewModel.submitStudy() }
                            }
                            .disabled(viewModel.isBusy)
                        }
                    }
                }
        }
        .onChange(of: detail.study.notes) { _, newValue in
            notes = newValue ?? ""
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .image, .jpeg, .png]
        ) { result in
            switch result {
            case .success(let url):
                handleImportedFile(url: url)
            case .failure(let error):
                viewModel.presentBanner("Import failed: \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            StudySummarySection(detail: detail)

            notesSection
            mediaSection
            uploadsSection
            signoffSection
            feedbackSection
        }
    }

    private func handleImportedFile(url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let tempURL = try copyToUploadsTemp(url: url)
            let contentType = tempURL.mimeType ?? "application/octet-stream"
            viewModel.enqueueUpload(fileURL: tempURL, contentType: contentType, study: detail.study)
        } catch {
            viewModel.presentBanner("Unable to prepare media: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 120)
            Button("Save Notes") {
                Task { await viewModel.saveNotes(notes) }
            }
            .disabled(viewModel.isBusy)
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        Section("Media") {
            if detail.media.isEmpty {
                Text("No media uploaded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detail.media, id: \.id) { media in
                    MediaRowView(media: media)
                }
            }

            if !deidentificationAcknowledged {
                Toggle("I confirm all media is de-identified", isOn: $deidentificationAcknowledged)
            } else {
                Button {
                    showImporter = true
                } label: {
                    Label("Attach Media", systemImage: "paperclip")
                }
            }
        }
    }

    @ViewBuilder
    private var uploadsSection: some View {
        if !uploadItems.isEmpty {
            Section("Active Uploads") {
                ForEach(uploadItems) { item in
                    UploadProgressRow(context: item.context, status: item.status)
                }
            }
        }
    }

    @ViewBuilder
    private var signoffSection: some View {
        if let signoff = detail.signoff {
            Section("Sign-off") {
                Text(signoff.status.rawValue.capitalized)
                    .font(.headline)
                if let signedAt = signoff.signedAt {
                    Text("Signed \(signedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if !detail.feedback.isEmpty {
            Section("Feedback") {
                ForEach(detail.feedback, id: \.id) { feedback in
                    FeedbackRowView(feedback: feedback)
                }
            }
        }
    }

    private func copyToUploadsTemp(url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCUS-Uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let targetURL = destination.appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.nonEmpty ?? "bin"))
        try FileManager.default.copyItem(at: url, to: targetURL)
        return targetURL
    }
}

private struct StudySummarySection: View {
    let detail: AppViewModel.StudyDetailState

    var body: some View {
        Section("Overview") {
            HStack {
                Label(detail.study.status.rawValue.capitalized.replacingOccurrences(of: "_", with: " "), systemImage: "tag.fill")
                Spacer()
            }
            Text("Created \(detail.study.createdAt.formatted(date: .abbreviated, time: .shortened))")
            if let submitted = detail.study.submittedAt {
                Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }
}

private struct UploadProgressRow: View {
    let context: TUSUploadService.UploadContext
    let status: TUSUploadService.UploadStatus

    var body: some View {
        let displayName = context.objectName.split(separator: "/").last.map(String.init) ?? context.objectName

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .lineLimit(1)
                Text(context.contentType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            switch status {
            case .queued:
                Text("Queued")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .uploading(let progress):
                ProgressView(value: progress)
                    .frame(width: 100)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let message):
                VStack(alignment: .trailing) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MediaRowView: View {
    let media: Media

    var body: some View {
        let displayName = media.storagePath.split(separator: "/").last.map(String.init) ?? media.storagePath

        VStack(alignment: .leading, spacing: 4) {
            Text(displayName)
                .lineLimit(1)
            Text(media.contentType)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct FeedbackRowView: View {
    let feedback: Feedback

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let rating = feedback.rating {
                Label("Rating \(rating)/5", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            Text(feedback.comments ?? "No comments")
            Text(feedback.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct UploadDisplay: Identifiable {
    let context: TUSUploadService.UploadContext
    let status: TUSUploadService.UploadStatus

    var id: UUID { context.id }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension URL {
    var mimeType: String? {
        guard let utType = UTType(filenameExtension: pathExtension) else { return nil }
        return utType.preferredMIMEType
    }
}
