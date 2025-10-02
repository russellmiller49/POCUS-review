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
                    Label("Choose from Files", systemImage: "folder")
                }
            }
            .onTapGesture {
                showPhotoPicker = true
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
        let type: CaseMedia.MediaType
        let uti = UTType(filenameExtension: url.pathExtension) ?? .data

        if uti.conforms(to: .movie) || uti.conforms(to: .video) {
            type = .video
        } else {
            type = .image
        }

        addMedia(type: type, fileURL: url)
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

struct MediaThumbnail: View {
    let media: CaseMedia
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: media.type == .image ? "photo" : "video.fill")
                        .foregroundStyle(.secondary)
                )

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .red)
                    .font(.caption)
            }
            .offset(x: 5, y: -5)
        }
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
