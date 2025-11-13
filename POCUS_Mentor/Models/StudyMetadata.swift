import Foundation

struct StudyMetadata: Codable {
    var caseTitle: String?
    var module: UltrasoundModule?
    var clinicalContext: String?
    var urgency: CaseUrgency?
    var patientAge: Int?
    var patientGender: String?
    var preliminaryFindings: String?
    var measurements: [ClinicalDetail]?
    var attendingContact: String?

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
}

struct DraftStudyInput {
    var title: String
    var module: UltrasoundModule
    var urgency: CaseUrgency
    var clinicalContext: String
    var patientAge: Int?
    var patientGender: String
    var preliminaryFindings: String
    var measurements: [ClinicalDetail]
    var attendingContact: String
    var attendingId: UUID?
}
