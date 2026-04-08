import Foundation

struct ReviewFeedbackPayload: Codable {
    var summary: String
    var detailedComments: [String]
    var teachingPoints: [String]
    var annotations: [ReviewAnnotationPayload]

    init(
        summary: String,
        detailedComments: [String],
        teachingPoints: [String],
        annotations: [ReviewAnnotationPayload] = []
    ) {
        self.summary = summary
        self.detailedComments = detailedComments
        self.teachingPoints = teachingPoints
        self.annotations = annotations
    }

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(from string: String?) -> ReviewFeedbackPayload? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReviewFeedbackPayload.self, from: data)
    }
}

struct ReviewAnnotationPayload: Codable, Identifiable {
    struct AnnotationColor: Codable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }

    struct AnnotationPointPayload: Codable {
        var x: Double
        var y: Double
    }

    let id: UUID
    var mediaId: UUID?
    var mediaName: String?
    var title: String
    var description: String
    var color: AnnotationColor
    var timestamp: Double?
    var points: [AnnotationPointPayload]
    var annotatedImageBase64: String?

    var imageData: Data? {
        guard let encoded = annotatedImageBase64 else { return nil }
        return Data(base64Encoded: encoded)
    }
}
