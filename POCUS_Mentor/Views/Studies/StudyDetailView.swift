import SwiftUI
import UniformTypeIdentifiers

struct StudyDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let detail: AppViewModel.StudyDetailState

    @State private var caseTitle: String
    @State private var module: UltrasoundModule?
    @State private var clinicalContext: String
    @State private var patientAge: Int
    @State private var patientGender: String
    @State private var preliminaryFindings: String
    @State private var attendingContact: String
    @State private var measurements: [ClinicalDetail]
    @State private var pendingMedia: [CaseMedia]
    @State private var existingCapturedMedia: [ExistingCaseMedia]
    @State private var processedMediaIDs: Set<UUID> = []
    @State private var showImporter = false

    @AppStorage("pocus.deidentificationAcknowledged") private var deidentificationAcknowledged: Bool = false

    private var isCardiacCase: Bool {
        if let module {
            return module == .cardiac
        }
        return detail.study.examType.caseInsensitiveCompare(UltrasoundModule.cardiac.rawValue) == .orderedSame
    }

    init(detail: AppViewModel.StudyDetailState) {
        self.detail = detail
        let metadata = detail.metadata
        let resolvedModule = metadata.module ?? UltrasoundModule(rawValue: detail.study.examType)
        _caseTitle = State(initialValue: metadata.caseTitle ?? detail.study.examType)
        _module = State(initialValue: resolvedModule)
        _clinicalContext = State(initialValue: metadata.clinicalContext ?? "")
        _patientAge = State(initialValue: metadata.patientAge ?? 60)
        _patientGender = State(initialValue: metadata.patientGender ?? "")
        _preliminaryFindings = State(initialValue: metadata.preliminaryFindings ?? "")
        _attendingContact = State(initialValue: metadata.attendingContact ?? "")
        _measurements = State(initialValue: metadata.measurements ?? [
            ClinicalDetail(label: "EF %", value: ""),
            ClinicalDetail(label: "LVIDd", value: ""),
            ClinicalDetail(label: "TR Vmax", value: "")
        ])
        _pendingMedia = State(initialValue: [])
        _existingCapturedMedia = State(initialValue: StudyDetailView.initialExistingMedia(detail: detail, module: resolvedModule))
    }

    private var overallFeedback: [Feedback] {
        detail.feedback.filter { $0.mediaId == nil }
    }

    private func feedback(for media: Media) -> [Feedback] {
        detail.feedback.filter { $0.mediaId == media.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                StudySummarySection(detail: detail, caseTitle: caseTitle)
                actionsSection
                caseOverviewSection
                patientSection
                clinicalContextSection
                interpretationSection
                measurementsSection
                attendingSection
                if let module {
                    Section("Media Capture") {
                        ModuleMediaUploadView(
                            module: module,
                            media: $pendingMedia,
                            existingMedia: $existingCapturedMedia
                        )
                    }
                }
                mediaSection
                uploadsSection
                signoffSection
                feedbackSection
            }
            .navigationTitle(module?.rawValue ?? detail.study.examType)
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
        .onChange(of: pendingMedia.count) { _, _ in
            processPendingMedia()
        }
        .onChange(of: module) { _, newValue in
            existingCapturedMedia = StudyDetailView.initialExistingMedia(detail: detail, module: newValue)
        }
    }

    // MARK: - Sections

    private var actionsSection: some View {
        Section("Actions") {
            if detail.study.status == .draft {
                Button("Save as Draft") {
                    Task { await saveDraftChanges() }
                }
                .disabled(viewModel.isBusy)
            }

            if viewModel.canSubmitStudy {
                Button("Submit for Review") {
                    Task { await submitForReview() }
                }
                .disabled(!viewModel.canSubmitStudy || viewModel.isBusy)
            }
        }
    }

    private func saveDraftChanges() async {
        guard detail.study.status == .draft else { return }
        await viewModel.updateMetadata(
            metadataForSave,
            successMessage: "Draft saved."
        )
    }

    private func submitForReview() async {
        guard viewModel.canSubmitStudy else { return }
        await viewModel.submitStudy(study: detail.study)
    }

    private var caseOverviewSection: some View {
        Section("Case Overview") {
            TextField("Case Title", text: $caseTitle)
            if let module {
                HStack {
                    Text("Module")
                    Spacer()
                    Text(module.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            saveButton(title: "Update Overview")
        }
    }

    private var patientSection: some View {
        Section("Patient Details") {
            Stepper(value: $patientAge, in: 1...110) {
                Text("Age: \(patientAge) years")
            }
            TextField("Gender", text: $patientGender)
            saveButton(title: "Save Patient Details")
        }
    }

    private var clinicalContextSection: some View {
        Section("Clinical Context") {
            TextEditor(text: $clinicalContext)
                .frame(minHeight: 100)
            saveButton(title: "Save Clinical Context")
        }
    }

    private var interpretationSection: some View {
        Section("Preliminary Interpretation") {
            TextEditor(text: $preliminaryFindings)
                .frame(minHeight: 120)
            saveButton(title: "Save Interpretation")
        }
    }

    private var measurementsSection: some View {
        Group {
            if isCardiacCase {
                Section("Measurements") {
                    ForEach(measurements.indices, id: \.self) { index in
                        HStack {
                            TextField("Label", text: $measurements[index].label)
                            Divider()
                            TextField("Value", text: $measurements[index].value)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Button("Add Measurement") {
                        measurements.append(ClinicalDetail(label: "", value: ""))
                    }
                    saveButton(title: "Save Measurements")
                }
            }
        }
    }

    private var attendingSection: some View {
        Section("Attending Contact") {
            TextField("Assign to Attending (Email or Name)", text: $attendingContact)
            saveButton(title: "Save Attending")
        }
    }

    private var mediaSection: some View {
        Section("Uploaded Media") {
            if detail.media.isEmpty {
                Text("No media uploaded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detail.media, id: \.id) { media in
                    VStack(alignment: .leading, spacing: 8) {
                        let label = detail.metadata.mediaLabel(for: media.id)
                        MediaRowView(media: media, label: label)
                        let comments = detail.feedback.filter { $0.mediaId == media.id }
                        if !comments.isEmpty {
                            MediaFeedbackList(feedback: comments)
                        }
                    }
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

    private var uploadsSection: some View {
        let items = viewModel.uploads(for: detail.study.id)
            .map { UploadDisplay(context: $0.0, status: $0.1) }

        return Section("Active Uploads") {
            if items.isEmpty {
                Text("No active uploads.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    UploadProgressRow(context: item.context, status: item.status)
                }
            }
        }
    }

    private var signoffSection: some View {
        Group {
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
    }

    private var feedbackSection: some View {
        Group {
            let overall = detail.feedback.filter { $0.mediaId == nil }
            if !overall.isEmpty {
                Section("Overall Feedback") {
                    ForEach(overall, id: \.id) { feedback in
                        FeedbackRowView(feedback: feedback)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func saveButton(title: String) -> some View {
        Button(title) {
            Task { await viewModel.updateMetadata(metadataForSave) }
        }
        .disabled(viewModel.isBusy)
    }

    private var metadataForSave: StudyMetadata {
        var metadata = detail.metadata
        metadata.caseTitle = caseTitle
        metadata.module = module
        metadata.clinicalContext = clinicalContext
        metadata.patientAge = patientAge
        metadata.patientGender = patientGender
        metadata.preliminaryFindings = preliminaryFindings
        metadata.measurements = isCardiacCase ? measurements : nil
        metadata.attendingContact = attendingContact
        return metadata
    }

    private func handleImportedFile(url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let tempURL = try copyToUploadsTemp(url: url)
            let mediaType: CaseMedia.MediaType
            if let utType = UTType(filenameExtension: tempURL.pathExtension),
               utType.conforms(to: UTType.movie) || utType.conforms(to: UTType.video) {
                mediaType = .video
            } else {
                mediaType = .image
            }
            let contentType = inferredContentType(for: tempURL, mediaType: mediaType)
            viewModel.enqueueUpload(fileURL: tempURL, contentType: contentType, study: detail.study)
        } catch {
            viewModel.presentBanner("Unable to prepare media: \(error.localizedDescription)")
        }
    }

    private func processPendingMedia() {
        for item in pendingMedia where !processedMediaIDs.contains(item.id) {
            do {
                let tempURL: URL
                if let url = item.fileURL {
                    tempURL = url
                } else if let data = item.data {
                    tempURL = try writeDataToTemporaryFile(data: data, type: item.type)
                } else {
                    continue
                }
                let contentType = inferredContentType(for: tempURL, mediaType: item.type)
                let label = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? item.echoView?.rawValue
                    : item.title
                viewModel.enqueueUpload(
                    fileURL: tempURL,
                    contentType: contentType,
                    study: detail.study,
                    label: label
                )
                processedMediaIDs.insert(item.id)
            } catch {
                viewModel.presentBanner("Upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func writeDataToTemporaryFile(data: Data, type: CaseMedia.MediaType) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCUS-Uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let ext = type == .video ? "mov" : "jpg"
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func copyToUploadsTemp(url: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCUS-Uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let target = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: url, to: target)
        return target
    }

    private func inferredContentType(for url: URL, mediaType: CaseMedia.MediaType) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension),
           let mime = utType.preferredMIMEType {
            return mime
        }
        switch mediaType {
        case .video: return "video/quicktime"
        case .image: return "image/jpeg"
        }
    }

    private static func initialExistingMedia(
        detail: AppViewModel.StudyDetailState,
        module: UltrasoundModule?
    ) -> [ExistingCaseMedia] {
        guard let module else { return [] }
        let lookup = module.requiredViews.reduce(into: [String: String]()) { dict, value in
            dict[value.normalizedMediaLabel] = value
        }
        return detail.media.compactMap { media in
            guard
                let label = detail.metadata.mediaLabel(for: media.id)?.normalizedMediaLabel,
                let resolved = lookup[label]
            else {
                return nil
            }
            let displayLabel = detail.metadata.mediaLabel(for: media.id) ?? resolved
            return ExistingCaseMedia(media: media, viewName: resolved, isRequired: true, label: displayLabel)
        }
    }
}

// MARK: - Helper views

private struct StudySummarySection: View {
    let detail: AppViewModel.StudyDetailState
    let caseTitle: String

    var body: some View {
        Section("Overview") {
            Text(caseTitle)
                .font(.headline)
            Text("Created \(detail.study.createdAt.formatted(date: .abbreviated, time: .shortened))")
            if let submitted = detail.study.submittedAt {
                Text("Submitted \(submitted.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            if let signoff = detail.signoff {
                Divider()
                Text("Sign-off")
                    .font(.headline)
                Text(signoff.status.rawValue.capitalized)
                if let signedAt = signoff.signedAt {
                    Text("Updated \(signedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    let label: String?

    var body: some View {
        let displayName = label?.isEmpty == false ? label! : media.displayName

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

private struct MediaFeedbackList: View {
    let feedback: [Feedback]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comments")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(feedback, id: \.id) { item in
                FeedbackRowView(feedback: item)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FeedbackRowView: View {
    let feedback: Feedback

    var body: some View {
        if let payload = ReviewFeedbackPayload.decode(from: feedback.comments) {
            FeedbackPayloadCard(feedback: feedback, payload: payload)
        } else {
            LegacyFeedbackCard(feedback: feedback)
        }
    }
}

private struct FeedbackPayloadCard: View {
    let feedback: Feedback
    let payload: ReviewFeedbackPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !payload.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(payload.summary)
            }

            if !payload.detailedComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detailed Comments")
                        .font(.subheadline.weight(.semibold))
                    ForEach(payload.detailedComments, id: \.self) { comment in
                        Label(comment, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
            }

            if !payload.teachingPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Teaching Points")
                        .font(.subheadline.weight(.semibold))
                    ForEach(payload.teachingPoints, id: \.self) { point in
                        Label(point, systemImage: "lightbulb")
                            .font(.subheadline)
                    }
                }
            }

            let annotations = payload.annotations.compactMap { $0.toFeedbackAnnotation() }
            if !annotations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annotations")
                        .font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(annotations) { annotation in
                                AnnotationCard(annotation: annotation)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack {
            if let rating = feedback.rating {
                Label("Rating \(rating)/5", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            Spacer()
            Text(feedback.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LegacyFeedbackCard: View {
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
    var normalizedMediaLabel: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
