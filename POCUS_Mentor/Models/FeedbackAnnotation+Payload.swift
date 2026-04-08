import SwiftUI

extension FeedbackAnnotation {
    func toPayload(mediaName: String?) -> ReviewAnnotationPayload? {
        guard let rgba = color.rgbaComponents ?? Color.red.rgbaComponents else { return nil }
        let colorPayload = ReviewAnnotationPayload.AnnotationColor(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
        let pointPayloads = points.map {
            ReviewAnnotationPayload.AnnotationPointPayload(x: Double($0.x), y: Double($0.y))
        }
        return ReviewAnnotationPayload(
            id: id,
            mediaId: mediaID,
            mediaName: mediaName,
            title: title,
            description: description,
            color: colorPayload,
            timestamp: timestamp,
            points: pointPayloads,
            annotatedImageBase64: annotatedImage?.base64EncodedString()
        )
    }
}

extension ReviewAnnotationPayload {
    func toFeedbackAnnotation() -> FeedbackAnnotation? {
        guard let color = Color(rgbaColor: color) else { return nil }
        let restoredPoints = points.map {
            AnnotationPoint(x: CGFloat($0.x), y: CGFloat($0.y))
        }
        return FeedbackAnnotation(
            id: id,
            title: title,
            description: description,
            color: color,
            mediaID: mediaId,
            timestamp: timestamp,
            points: restoredPoints,
            annotatedImage: imageData
        )
    }
}
