import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation

struct MediaDropZone: View {
    let echoView: EchoView
    @Binding var media: [CaseMedia]
    @State private var isTargeted = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showImportOptions = false

    private var viewMedia: [CaseMedia] {
        media.filter { $0.echoView == echoView }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(echoView.shortName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewMedia.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.blue : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                    )

                if viewMedia.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Drop media here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewMedia) { item in
                                MediaThumbnail(media: item, onRemove: {
                                    media.removeAll { $0.id == item.id }
                                })
                            }
                        }
                        .padding(8)
                    }
                    .frame(minHeight: 80)
                }
            }
            .onDrop(of: [.image, .movie], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            .contextMenu {
                Button(action: { showPhotoPicker = true }) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                Button(action: { showDocumentPicker = true }) {
                    Label("Import from Files & Cloud", systemImage: "folder.badge.plus")
                }
            }
            .onTapGesture {
                showImportOptions = true
            }
            .confirmationDialog("Add media", isPresented: $showImportOptions, titleVisibility: .visible) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Photos Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Files, iCloud, or Drive", systemImage: "folder.badge.plus")
                }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .any(of: [.images, .videos])
            )
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(allowedTypes: [.image, .movie]) { urls in
                    for url in urls {
                        handleDocumentURL(url)
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    await loadPhotos(from: newItems)
                    selectedPhotos = []
                }
            }

            HStack(spacing: 12) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Add from Photos", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Add from Files & Cloud", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
            .padding(.top, 4)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Check for video first
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { item, error in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(type: .video, fileURL: url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Movie.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.mpeg4Movie.identifier) { item, error in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(type: .video, fileURL: url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.quickTimeMovie.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.quickTimeMovie.identifier) { item, error in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            addMedia(type: .video, fileURL: url)
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            addMedia(type: .image, data: image.jpegData(compressionQuality: 0.8))
                        }
                    }
                }
            }
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            // Check if it's a video
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                DispatchQueue.main.async {
                    addMedia(type: .video, fileURL: movie.url)
                }
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                DispatchQueue.main.async {
                    addMedia(type: .image, data: data)
                }
            }
        }
    }

    private func handleDocumentURL(_ url: URL) {
        let uti = UTType(filenameExtension: url.pathExtension) ?? .data
        let determinedType: CaseMedia.MediaType = (uti.conforms(to: .movie) || uti.conforms(to: .video)) ? .video : .image

        Task.detached(priority: .userInitiated) {
            guard let storedURL = MediaDropZone.persistImportedFile(originalURL: url) else { return }
            await MainActor.run {
                addMedia(type: determinedType, fileURL: storedURL)
            }
        }
    }

    private nonisolated static func persistImportedFile(originalURL: URL) -> URL? {
        let fileManager = FileManager.default
        let destinationFolder = fileManager.temporaryDirectory.appendingPathComponent("ImportedMedia", isDirectory: true)

        do {
            if !fileManager.fileExists(atPath: destinationFolder.path) {
                try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            }

            let uniqueName = UUID().uuidString + "_" + originalURL.lastPathComponent
            let destinationURL = destinationFolder.appendingPathComponent(uniqueName)

            let didAccessSecurityScope = originalURL.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScope {
                    originalURL.stopAccessingSecurityScopedResource()
                }
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            do {
                try fileManager.copyItem(at: originalURL, to: destinationURL)
            } catch {
                // If direct copy fails (e.g., file already in app container), attempt move
                try fileManager.moveItem(at: originalURL, to: destinationURL)
            }

            return destinationURL
        } catch {
            print("Failed to persist imported file: \(error.localizedDescription)")
            return nil
        }
    }

    private func addMedia(type: CaseMedia.MediaType, data: Data? = nil, fileURL: URL? = nil) {
        let newMedia = CaseMedia(
            id: UUID(),
            title: echoView.shortName,
            type: type,
            thumbnailName: type == .image ? "photo" : "video",
            description: "",
            echoView: echoView,
            fileURL: fileURL
        )
        media.append(newMedia)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var media: [CaseMedia] = []

        var body: some View {
            VStack {
                MediaDropZone(echoView: .apical4Chamber, media: $media)
                MediaDropZone(echoView: .plaxStandard, media: $media)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

// Video transferable for PhotosPicker
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// Document Picker for cloud storage
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void

        init(onPicked: @escaping ([URL]) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPicked(urls)
        }
    }
}

