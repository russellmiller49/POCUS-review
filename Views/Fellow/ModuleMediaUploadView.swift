import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ModuleMediaUploadView: View {
    let module: UltrasoundModule
    @Binding var media: [CaseMedia]
    @State private var showAdditionalViews = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(module.rawValue)
                        .font(.headline)
                    Text(module.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(requiredMediaCount)/\(module.requiredViews.count) required")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(progressColor.opacity(0.2))
                    .clipShape(Capsule())
            }

            // Required Views
            VStack(alignment: .leading, spacing: 12) {
                Text("Required Views")
                    .font(.subheadline.bold())

                ForEach(module.requiredViews, id: \.self) { viewName in
                    ModuleViewDropZone(
                        viewName: viewName,
                        module: module,
                        media: $media,
                        isRequired: true
                    )
                }
            }

            // Additional Views Toggle
            DisclosureGroup("Additional Windows (Optional)", isExpanded: $showAdditionalViews) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add supplementary images or videos")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: addAdditionalView) {
                        Label("Add Additional Window", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    // Show additional media
                    ForEach(media.filter { $0.isAdditional }) { item in
                        HStack {
                            Image(systemName: item.type == .image ? "photo" : "video.fill")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                if !item.description.isEmpty {
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: { removeMedia(item) }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var requiredMediaCount: Int {
        media.filter { $0.isRequired && !$0.title.isEmpty }.count
    }

    private var progressColor: Color {
        let progress = Double(requiredMediaCount) / Double(module.requiredViews.count)
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .orange }
        return .red
    }

    private func addAdditionalView() {
        let newMedia = CaseMedia(
            id: UUID(),
            title: "Additional Window \(media.filter { $0.isAdditional }.count + 1)",
            type: .image,
            thumbnailName: "photo",
            description: "",
            echoView: nil,
            fileURL: nil,
            isRequired: false,
            isAdditional: true
        )
        media.append(newMedia)
    }

    private func removeMedia(_ item: CaseMedia) {
        media.removeAll { $0.id == item.id }
    }
}

struct ModuleViewDropZone: View {
    let viewName: String
    let module: UltrasoundModule
    @Binding var media: [CaseMedia]
    let isRequired: Bool

    @State private var isTargeted = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false

    private var viewMedia: [CaseMedia] {
        media.filter { $0.title == viewName && $0.isRequired == isRequired }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if !viewMedia.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? module.color : Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [8])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? module.color.opacity(0.1) : Color.clear)
                    )

                if viewMedia.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundStyle(module.color)
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
                maxSelectionCount: 5,
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
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { item, error in
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
            title: viewName,
            type: type,
            thumbnailName: type == .image ? "photo" : "video",
            description: "",
            echoView: nil,
            fileURL: fileURL,
            isRequired: isRequired,
            isAdditional: !isRequired
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
