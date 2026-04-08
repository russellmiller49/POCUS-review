import Foundation

struct StudyMetadata: Codable {
    var caseTitle: String?
    var module: UltrasoundModule?
    var clinicalContext: String?
    var patientAge: Int?
    var patientGender: String?
    var preliminaryFindings: String?
    var measurements: [ClinicalDetail]?
    var attendingContact: String?
    var mediaLabels: [UUID: String]?

    static func decode(from notes: String?) -> StudyMetadata {
        guard let notes,
              let data = notes.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(StudyMetadata.self, from: data) else {
            return StudyMetadata()
        }
        return metadata
    }

    func encode() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func mediaLabel(for mediaId: UUID) -> String? {
        mediaLabels?[mediaId]
    }

    mutating func setMediaLabel(_ label: String?, for mediaId: UUID) {
        var labels = mediaLabels ?? [:]
        labels[mediaId] = label
        mediaLabels = labels
    }
}

struct DraftStudyInput {
    var title: String
    var module: UltrasoundModule
    var clinicalContext: String
    var patientAge: Int?
    var patientGender: String
    var preliminaryFindings: String
    var measurements: [ClinicalDetail]
    var attendingContact: String
    var attendingId: UUID?
}
