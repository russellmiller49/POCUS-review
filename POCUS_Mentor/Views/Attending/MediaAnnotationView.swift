import SwiftUI
import AVKit
import UIKit

struct MediaAnnotationView: View {
    @Environment(\.dismiss) private var dismiss

    let media: CaseMedia
    @Binding var annotations: [FeedbackAnnotation]

    @State private var player: AVPlayer?
    @State private var frozenFrame: UIImage?
    @State private var isFrozen = false
    @State private var currentAnnotation: FeedbackAnnotation?
    @State private var annotationPoints: [AnnotationPoint] = []
    @State private var annotationTitle: String = ""
    @State private var annotationDescription: String = ""
    @State private var selectedColor: Color = .red
    @State private var showAnnotationForm = false

    let colors: [Color] = [.red, .blue, .green, .orange, .yellow, .purple]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Media Display Area
                GeometryReader { geometry in
                    ZStack {
                        if isFrozen, let frozenFrame = frozenFrame {
                            // Frozen frame with annotations
                            ZStack {
                                Image(uiImage: frozenFrame)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)

                                AnnotationDrawingView(
                                    points: $annotationPoints,
                                    color: selectedColor,
                                    existingAnnotations: annotations.filter { $0.mediaID == media.id }
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        } else if media.fileURL != nil, media.type == .video {
                            // Video player
                            if let player = player {
                                VideoPlayer(player: player)
                                    .onAppear { player.play() }
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        } else {
                            // Placeholder
                            Color.black
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(height: 500)

                // Controls
                VStack(spacing: 16) {
                    // Freeze/Unfreeze
                    HStack(spacing: 16) {
                        if !isFrozen {
                            Button(action: freezeFrame) {
                                Label("Freeze Frame", systemImage: "pause.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(media.type != .video || player == nil)
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

                    // Color Picker (when frozen)
                    if isFrozen {
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

                    // Existing Annotations
                    if !annotations.filter({ $0.mediaID == media.id }).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Annotations on this view")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(annotations.filter { $0.mediaID == media.id }) { annotation in
                                        AnnotationChip(annotation: annotation) {
                                            if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
                                                annotations.remove(at: index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(media.echoView?.rawValue ?? media.title)
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
            .onAppear {
                if let url = media.fileURL, media.type == .video {
                    player = AVPlayer(url: url)
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    private func freezeFrame() {
        guard let player = player else { return }

        player.pause()

        // Capture current frame
        let currentTime = player.currentTime()
        let asset = player.currentItem?.asset

        guard let asset = asset else { return }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero

        if #available(iOS 18.0, *) {
            imageGenerator.generateCGImageAsynchronously(for: currentTime) { cgImage, _, error in
                if let cgImage = cgImage {
                    DispatchQueue.main.async {
                        let image = UIImage(cgImage: cgImage)
                        withAnimation(.easeInOut) {
                            self.frozenFrame = image
                            self.isFrozen = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                } else if let error = error {
                    print("Error capturing frame: \(error)")
                } else {
                    print("Unknown error capturing frame")
                }
            }
        } else {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: currentTime, actualTime: nil)
                frozenFrame = UIImage(cgImage: cgImage)
                isFrozen = true
            } catch {
                print("Error capturing frame: \(error)")
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
              !annotationTitle.isEmpty else { return }

        // Capture annotated image
        var annotatedImage: Data?
        if let frozenFrame = frozenFrame,
           frozenFrame.size.width > 0,
           frozenFrame.size.height > 0 {

            // Ensure size is valid and not too large
            let maxDimension: CGFloat = 2048
            var renderSize = frozenFrame.size
            if renderSize.width > maxDimension || renderSize.height > maxDimension {
                let scale = min(maxDimension / renderSize.width, maxDimension / renderSize.height)
                renderSize = CGSize(width: renderSize.width * scale, height: renderSize.height * scale)
            }

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true

            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            let image = renderer.image { context in
                // Draw the frozen frame
                if let cgImage = frozenFrame.cgImage {
                    context.cgContext.draw(cgImage, in: CGRect(origin: .zero, size: renderSize))
                }

                // Draw annotation lines
                context.cgContext.setStrokeColor(UIColor(selectedColor).cgColor)
                context.cgContext.setLineWidth(3)
                context.cgContext.setLineCap(.round)
                context.cgContext.setLineJoin(.round)

                if annotationPoints.count > 1 {
                    context.cgContext.beginPath()
                    let firstPoint = CGPoint(
                        x: annotationPoints[0].x * renderSize.width,
                        y: annotationPoints[0].y * renderSize.height
                    )
                    context.cgContext.move(to: firstPoint)

                    for i in 1..<annotationPoints.count {
                        let point = CGPoint(
                            x: annotationPoints[i].x * renderSize.width,
                            y: annotationPoints[i].y * renderSize.height
                        )
                        context.cgContext.addLine(to: point)
                    }
                    context.cgContext.strokePath()
                }
            }
            annotatedImage = image.jpegData(compressionQuality: 0.8)
        }

        let annotation = FeedbackAnnotation(
            id: UUID(),
            title: annotationTitle,
            description: annotationDescription,
            color: selectedColor,
            mediaID: media.id,
            timestamp: player?.currentTime().seconds,
            points: annotationPoints,
            annotatedImage: annotatedImage
        )

        annotations.append(annotation)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Reset
        annotationPoints = []
        annotationTitle = ""
        annotationDescription = ""
        showAnnotationForm = false
        unfreeze()
    }
}

struct AnnotationDrawingView: View {
    @Binding var points: [AnnotationPoint]
    let color: Color
    let existingAnnotations: [FeedbackAnnotation]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear

                // Existing annotations
                ForEach(existingAnnotations) { annotation in
                    Path { path in
                        for (startPoint, endPoint) in zip(annotation.points, annotation.points.dropFirst()) {
                            let start = CGPoint(
                                x: startPoint.x * geometry.size.width,
                                y: startPoint.y * geometry.size.height
                            )
                            let end = CGPoint(
                                x: endPoint.x * geometry.size.width,
                                y: endPoint.y * geometry.size.height
                            )
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                    }
                    .stroke(annotation.color, lineWidth: 3)
                }

                // Current drawing
                Path { path in
                    for (startPoint, endPoint) in zip(points, points.dropFirst()) {
                        let start = CGPoint(
                            x: startPoint.x * geometry.size.width,
                            y: startPoint.y * geometry.size.height
                        )
                        let end = CGPoint(
                            x: endPoint.x * geometry.size.width,
                            y: endPoint.y * geometry.size.height
                        )
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                }
                .stroke(color, lineWidth: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = AnnotationPoint(
                            x: value.location.x / geometry.size.width,
                            y: value.location.y / geometry.size.height
                        )
                        points.append(point)
                    }
            )
        }
    }
}

struct AnnotationChip: View {
    let annotation: FeedbackAnnotation
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(annotation.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.title)
                    .font(.caption.bold())
                if !annotation.description.isEmpty {
                    Text(annotation.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

struct AnnotationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var description: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Annotation Details") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
