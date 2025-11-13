import SwiftUI
import UniformTypeIdentifiers

struct StudyDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let detail: AppViewModel.StudyDetailState

    @State private var caseTitle: String
    @State private var module: UltrasoundModule?
    @State private var urgency: CaseUrgency
    @State private var clinicalContext: String
    @State private var patientAge: Int
    @State private var patientGender: String
    @State private var preliminaryFindings: String
    @State private var attendingContact: String
    @State private var measurements: [ClinicalDetail]
    @State private var pendingMedia: [CaseMedia]
    @State private var processedMediaIDs: Set<UUID> = []
    @State private var showImporter = false

    @AppStorage("pocus.deidentificationAcknowledged") private var deidentificationAcknowledged: Bool = false

    init(detail: AppViewModel.StudyDetailState) {
        self.detail = detail
        let metadata = detail.metadata
        _caseTitle = State(initialValue: metadata.caseTitle ?? detail.study.examType)
        _module = State(initialValue: metadata.module ?? UltrasoundModule(rawValue: detail.study.examType))
        _urgency = State(initialValue: metadata.urgency ?? .routine)
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
    }

    var body: some View {
        NavigationStack {
            Form {
                StudySummarySection(detail: detail, caseTitle: caseTitle, urgency: urgency)
                caseOverviewSection
                patientSection
                clinicalContextSection
                interpretationSection
                measurementsSection
                attendingSection
                if let module {
                    Section("Media Capture") {
                        ModuleMediaUploadView(module: module, media: $pendingMedia)
                    }
                }
                mediaSection
                uploadsSection
                signoffSection
                feedbackSection
            }
            .navigationTitle(module?.rawValue ?? detail.study.examType)
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
        .onChange(of: pendingMedia.count) { _ in
            processPendingMedia()
        }
    }

    // MARK: - Sections

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
            Picker("Urgency", selection: $urgency) {
                ForEach(CaseUrgency.allCases) { option in
                    Text(option.displayName).tag(option)
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
            if !detail.feedback.isEmpty {
                Section("Feedback") {
                    ForEach(detail.feedback, id: \.id) { feedback in
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
        metadata.urgency = urgency
        metadata.clinicalContext = clinicalContext
        metadata.patientAge = patientAge
        metadata.patientGender = patientGender
        metadata.preliminaryFindings = preliminaryFindings
        metadata.measurements = measurements
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
                viewModel.enqueueUpload(fileURL: tempURL, contentType: contentType, study: detail.study)
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
}

// MARK: - Helper views

private struct StudySummarySection: View {
    let detail: AppViewModel.StudyDetailState
    let caseTitle: String
    let urgency: CaseUrgency

    var body: some View {
        Section("Overview") {
            Text(caseTitle)
                .font(.headline)
            Label(urgency.displayName, systemImage: "bolt.heart")
                .font(.caption)
                .padding(6)
                .background(urgency.color.opacity(0.15))
                .clipShape(Capsule())
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
