import SwiftUI
import UniformTypeIdentifiers

struct CaseUploadWizard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var caseTitle: String = ""
    @State private var clinicalContext: String = ""
    @State private var patientAge: Int = 60
    @State private var patientGender: String = "Female"
    @State private var preliminaryFindings: String = ""
    @State private var measurements: [ClinicalDetail] = [
        .init(label: "EF %", value: ""),
        .init(label: "LVIDd", value: ""),
        .init(label: "TR Vmax", value: "")
    ]
    @State private var uploadedMedia: [CaseMedia] = []
    @State private var selectedAttendingID: UUID?
    @State private var selectedModule: UltrasoundModule = .cardiac
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Case Overview") {
                    TextField("Case Title", text: $caseTitle)

                    Picker("Ultrasound Module", selection: $selectedModule) {
                        ForEach(UltrasoundModule.allCases) { module in
                            HStack {
                                Circle()
                                    .fill(module.color)
                                    .frame(width: 12, height: 12)
                                Text(module.rawValue)
                            }
                            .tag(module)
                        }
                    }

                    LabeledContent("Fellow") {
                        Text(fellowDisplayName)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Assign to Attending", selection: $selectedAttendingID) {
                        Text("Select Attending").tag(UUID?.none)
                        ForEach(attendingOptions) { attending in
                            Text(attending.fullName ?? attending.email)
                                .tag(UUID?.some(attending.id))
                        }
                    }
                    if attendingOptions.isEmpty {
                        Text("No approved attendings are available for this institution yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Patient Details") {
                    Stepper(value: $patientAge, in: 1...110) {
                        Text("Age: \(patientAge) years")
                    }
                    TextField("Gender", text: $patientGender)
                    TextField("Clinical Context", text: $clinicalContext, axis: .vertical)
                }
                
                Section("Preliminary Interpretation") {
                    TextEditor(text: $preliminaryFindings)
                        .frame(minHeight: 120)
                }
                
                if selectedModule == .cardiac {
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
                            measurements.append(.init(label: "", value: ""))
                        }
                    }
                }
                
                Section {
                    ModuleMediaUploadView(module: selectedModule, media: $uploadedMedia)
                } header: {
                    HStack {
                        Text("\(selectedModule.rawValue) - Required Views")
                        Spacer()
                        Text("\(uploadedMedia.filter { $0.isRequired }.count)/\(selectedModule.requiredViews.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Upload Guidelines") {
                    Label("Capture high quality images for each view", systemImage: "photo")
                    Label("Include Doppler sweeps where relevant", systemImage: "waveform")
                    Label("Attach video loops for dynamic findings", systemImage: "play.rectangle")
                    Label("Organize media by standard echo views", systemImage: "square.grid.2x2")
                }
            }
            .navigationTitle("New Case Submission")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit", action: submitCase)
                        .disabled(!canSubmit)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Case submitted", isPresented: $showConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your case has been assigned to \(selectedAttending?.fullName ?? selectedAttending?.email ?? "an attending") for review. You'll be notified when feedback is available.")
            }
        }
        .task {
            if viewModel.attendingDirectory.isEmpty {
                await viewModel.loadAttendingDirectory()
            }
        }
        .onChange(of: viewModel.attendingDirectory) { _, newValue in
            if selectedAttendingID == nil {
                selectedAttendingID = newValue.first?.id
            }
        }
    }

    private func submitCase() {
        guard canSubmit else { return }
        guard let attending = selectedAttending else {
            viewModel.presentBanner("Select an attending before submitting.")
            return
        }

        Task {
            let filteredMeasurements = measurements.filter { !$0.label.isEmpty || !$0.value.isEmpty }
            let input = DraftStudyInput(
                title: caseTitle,
                module: selectedModule,
                clinicalContext: clinicalContext,
                patientAge: patientAge,
                patientGender: patientGender,
                preliminaryFindings: preliminaryFindings,
                measurements: selectedModule == .cardiac ? filteredMeasurements : [],
                attendingContact: attending.fullName ?? attending.email,
                attendingId: attending.id
            )
            guard let study = await viewModel.createDraftStudy(input: input) else { return }
            let uploadsSuccessful = await uploadInitialMedia(for: study)
            guard uploadsSuccessful else { return }
            await viewModel.submitStudy(study: study)
            await MainActor.run {
                uploadedMedia.removeAll()
                showConfirmation = true
            }
        }
    }

    private var fellowDisplayName: String {
        if let name = viewModel.currentProfile?.fullName, !name.isEmpty {
            return name
        }
        if let email = viewModel.currentProfile?.email {
            return email
        }
        if let fallbackEmail = viewModel.currentSession?.profile.email {
            return fallbackEmail
        }
        return "Fellow"
    }

    private var attendingOptions: [UserProfileSummary] {
        viewModel.attendingDirectory
            .sorted {
                ($0.fullName ?? $0.email)
                    .localizedCaseInsensitiveCompare($1.fullName ?? $1.email) == .orderedAscending
            }
    }

    private var selectedAttending: UserProfileSummary? {
        guard let id = selectedAttendingID else { return nil }
        return attendingOptions.first { $0.id == id }
    }

    private var canSubmit: Bool {
        !caseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAttending != nil &&
        !viewModel.isBusy
    }
}

#Preview {
    CaseUploadWizard()
        .environmentObject(AppViewModel())
}

// MARK: - Upload helpers

extension CaseUploadWizard {
    private func uploadInitialMedia(for study: Study) async -> Bool {
        let mediaItems = await MainActor.run { uploadedMedia }
        guard !mediaItems.isEmpty else { return true }
        var handleIDs: [UUID] = []

        for item in mediaItems {
            do {
                let fileURL = try prepareFileURL(for: item)
                let contentType = inferContentType(for: item, url: fileURL)
                let label = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? item.echoView?.rawValue
                    : item.title
                if let handleID = await MainActor.run(body: {
                    viewModel.enqueueUpload(
                        fileURL: fileURL,
                        contentType: contentType,
                        study: study,
                        label: label
                    )
                }) {
                    handleIDs.append(handleID)
                } else {
                    return false
                }
            } catch {
                await MainActor.run {
                    viewModel.presentBanner("Upload failed: \(error.localizedDescription)")
                }
                return false
            }
        }

        return await waitForUploads(handleIDs: handleIDs)
    }

    private func waitForUploads(handleIDs: [UUID]) async -> Bool {
        guard !handleIDs.isEmpty else { return true }
        let deadline = Date().addingTimeInterval(180)

        while Date() < deadline {
            let statuses = await MainActor.run {
                handleIDs.map { viewModel.uploadStatuses[$0] }
            }

            var allComplete = true
            for status in statuses {
                switch status {
                case .completed?:
                    continue
                case .failed(let message)?:
                    await MainActor.run {
                        viewModel.presentBanner("Upload failed: \(message)")
                    }
                    return false
                case .uploading?, .queued?, nil:
                    allComplete = false
                }
            }

            if allComplete { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        await MainActor.run {
            viewModel.presentBanner("Uploads timed out. Please try again.")
        }
        return false
    }

    private func prepareFileURL(for media: CaseMedia) throws -> URL {
        if let url = media.fileURL {
            return url
        }
        if let data = media.data {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("WizardUploads", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let ext = media.type == .video ? "mov" : "jpg"
            let tempURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        }
        throw UploadPreparationError.missingData
    }

    private func inferContentType(for media: CaseMedia, url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension),
           let mime = utType.preferredMIMEType {
            return mime
        }
        switch media.type {
        case .video:
            return "video/quicktime"
        case .image:
            return "image/jpeg"
        }
    }

    private enum UploadPreparationError: LocalizedError {
        case missingData

        var errorDescription: String? {
            switch self {
            case .missingData:
                return "Unable to read media data."
            }
        }
    }
}
