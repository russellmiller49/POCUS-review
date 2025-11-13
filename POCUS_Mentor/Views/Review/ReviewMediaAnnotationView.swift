import SwiftUI
import AVKit
import UIKit

struct ReviewMediaAnnotationView: View {
    @Environment(\.dismiss) private var dismiss

    let media: Media
    let signedURL: URL
    @Binding var annotations: [FeedbackAnnotation]

    @State private var player: AVPlayer?
    @State private var frozenFrame: UIImage?
    @State private var isFrozen = false
    @State private var annotationPoints: [AnnotationPoint] = []
    @State private var annotationTitle: String = ""
    @State private var annotationDescription: String = ""
    @State private var selectedColor: Color = .red
    @State private var showAnnotationForm = false
    @State private var isLoadingStill = false
    @State private var loadError: String?

    private let colors: [Color] = [.red, .blue, .green, .orange, .yellow, .purple]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        if isVideo {
                            videoSurface(size: geometry.size)
                        } else {
                            stillImageSurface(size: geometry.size)
                        }
                    }
                }
                .frame(height: 500)

                controlPanel
                    .padding()
            }
            .navigationTitle(media.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAnnotationForm) {
                AnnotationFormView(
                    title: $annotationTitle,
                    description: $annotationDescription,
                    onSave: saveAnnotation
                )
            }
            .task {
                await prepareMedia()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    private var isVideo: Bool {
        media.isVideo
    }

    private var existingAnnotations: [FeedbackAnnotation] {
        annotations.filter { $0.mediaID == media.id }
    }

    private func videoSurface(size: CGSize) -> some View {
        Group {
            if isFrozen, let frozenFrame {
                annotatedImageView(frozenFrame, size: size)
            } else if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
        }
    }

    private func stillImageSurface(size: CGSize) -> some View {
        Group {
            if let frozenFrame {
                annotatedImageView(frozenFrame, size: size)
            } else if isLoadingStill {
                Color.black.opacity(0.05)
                    .overlay(ProgressView())
            } else if let loadError {
                Text(loadError)
                    .foregroundStyle(.secondary)
            } else {
                Color.black.opacity(0.05)
            }
        }
    }

    private func annotatedImageView(_ image: UIImage, size: CGSize) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)

            AnnotationDrawingView(
                points: $annotationPoints,
                color: selectedColor,
                existingAnnotations: existingAnnotations
            )
            .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private var controlPanel: some View {
        VStack(spacing: 16) {
            if isVideo {
                videoControls
            } else if frozenFrame != nil {
                Button(action: { showAnnotationForm = true }) {
                    Label("Save Annotation", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(annotationPoints.isEmpty)
            }

            colorPicker

            if !existingAnnotations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Annotations on this media")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(existingAnnotations) { annotation in
                                AnnotationChip(annotation: annotation) {
                                    annotations.removeAll { $0.id == annotation.id }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var videoControls: some View {
        HStack(spacing: 16) {
            if !isFrozen {
                Button(action: freezeFrame) {
                    Label("Freeze Frame", systemImage: "pause.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(player == nil)
            } else {
                Button(action: unfreeze) {
                    Label("Resume Video", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: { showAnnotationForm = true }) {
                    Label("Save Annotation", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(annotationPoints.isEmpty)
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            Text("Color:")
                .font(.subheadline)
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
            Spacer()
            Button("Clear") {
                annotationPoints = []
            }
            .disabled(annotationPoints.isEmpty)
        }
    }

    private func prepareMedia() async {
        if isVideo {
            await MainActor.run {
                player = AVPlayer(url: signedURL)
            }
        } else {
            await loadStillImage()
        }
    }

    private func loadStillImage() async {
        isLoadingStill = true
        defer { isLoadingStill = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: signedURL)
            guard let image = UIImage(data: data) else {
                loadError = "Unable to load image."
                return
            }
            await MainActor.run {
                self.frozenFrame = image
                self.isFrozen = true
            }
        } catch {
            loadError = "Failed to load image."
        }
    }

    private func freezeFrame() {
        guard let player else { return }
        player.pause()
        let currentTime = player.currentTime()
        let asset = player.currentItem?.asset ?? AVAsset(url: signedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        if #available(iOS 18.0, *) {
            generator.generateCGImageAsynchronously(for: currentTime) { cgImage, _, error in
                if let cgImage {
                    let image = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut) {
                            self.frozenFrame = image
                            self.isFrozen = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                } else if let error {
                    print("Frame capture error: \(error)")
                }
            }
        } else {
            do {
                let cgImage = try generator.copyCGImage(at: currentTime, actualTime: nil)
                frozenFrame = UIImage(cgImage: cgImage)
                isFrozen = true
            } catch {
                print("Frame capture error: \(error)")
            }
        }
    }

    private func unfreeze() {
        withAnimation(.easeInOut) {
            isFrozen = false
            frozenFrame = nil
            annotationPoints = []
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        player?.play()
    }

    private func saveAnnotation() {
        guard !annotationPoints.isEmpty,
              !annotationTitle.isEmpty,
              let baseImage = frozenFrame else { return }

        let annotatedImage = renderAnnotation(on: baseImage)
        let annotation = FeedbackAnnotation(
            id: UUID(),
            title: annotationTitle,
            description: annotationDescription,
            color: selectedColor,
            mediaID: media.id,
            timestamp: isVideo ? player?.currentTime().seconds : nil,
            points: annotationPoints,
            annotatedImage: annotatedImage
        )

        annotations.append(annotation)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        annotationPoints = []
        annotationTitle = ""
        annotationDescription = ""
        showAnnotationForm = false
        if isVideo {
            unfreeze()
        }
    }

    private func renderAnnotation(on image: UIImage) -> Data? {
        let renderSize = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let rendered = renderer.image { context in
            if let cgImage = image.cgImage {
                context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: renderSize))
            }
            context.cgContext.setStrokeColor(UIColor(selectedColor).cgColor)
            context.cgContext.setLineWidth(3)
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)
            if annotationPoints.count > 1 {
                context.cgContext.beginPath()
                let first = CGPoint(x: annotationPoints[0].x * renderSize.width, y: annotationPoints[0].y * renderSize.height)
                context.cgContext.move(to: first)
                for point in annotationPoints.dropFirst() {
                    let converted = CGPoint(x: point.x * renderSize.width, y: point.y * renderSize.height)
                    context.cgContext.addLine(to: converted)
                }
                context.cgContext.strokePath()
            }
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }
}
