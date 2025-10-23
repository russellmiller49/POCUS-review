import Foundation
import Combine
import Supabase

protocol StudyServicing: Sendable {
    func fetchStudies(institutionId: UUID, statuses: [StudyStatus]?) async throws -> [Study]
    func createStudy(_ payload: NewStudyRequest) async throws -> Study
    func updateStudyStatus(studyId: UUID, status: StudyStatus, submittedAt: Date?) async throws -> Study
    func updateStudyNotes(studyId: UUID, notes: String?) async throws -> Study
    func insertMedia(_ payload: NewMediaRequest) async throws -> Media
    func insertFeedback(_ payload: NewFeedbackRequest) async throws -> Feedback
    func upsertSignoff(_ payload: UpsertSignoffRequest) async throws -> Signoff
    func fetchMedia(for studyId: UUID) async throws -> [Media]
    func fetchFeedback(for studyId: UUID) async throws -> [Feedback]
    func fetchSignoff(for studyId: UUID) async throws -> Signoff?
}

struct SupabaseStudyService: StudyServicing {
    private let clientProvider: SupabaseClientProviding

    init(clientProvider: SupabaseClientProviding = SupabaseClientManager.shared) {
        self.clientProvider = clientProvider
    }

    private var client: SupabaseClient { clientProvider.client }

    func fetchStudies(institutionId: UUID, statuses: [StudyStatus]?) async throws -> [Study] {
        var builder: PostgrestFilterBuilder = client
            .from("studies")
            .select()
            .eq("institution_id", value: institutionId)

        if let statuses, !statuses.isEmpty {
            builder = builder.`in`(
                "status",
                values: statuses.map(\.rawValue)
            )
        }

        let response: PostgrestResponse<[StudyRow]> = try await builder
            .order("created_at", ascending: false)
            .execute()
        return response.value.map(\.model)
    }

    func createStudy(_ payload: NewStudyRequest) async throws -> Study {
        let response: PostgrestResponse<StudyRow> = try await client
            .from("studies")
            .insert(payload, returning: .representation)
            .single()
            .execute()

        return response.value.model
    }

    func fetchMedia(for studyId: UUID) async throws -> [Media] {
        let response: PostgrestResponse<[MediaRow]> = try await client
            .from("media")
            .select()
            .eq("study_id", value: studyId)
            .order("created_at", ascending: false)
            .execute()
        return response.value.map(\.model)
    }

    func fetchFeedback(for studyId: UUID) async throws -> [Feedback] {
        let response: PostgrestResponse<[FeedbackRow]> = try await client
            .from("feedback")
            .select()
            .eq("study_id", value: studyId)
            .order("created_at", ascending: false)
            .execute()
        return response.value.map(\.model)
    }

    func fetchSignoff(for studyId: UUID) async throws -> Signoff? {
        let response: PostgrestResponse<[SignoffRow]> = try await client
            .from("signoffs")
            .select()
            .eq("study_id", value: studyId)
            .limit(1)
            .execute()
        return response.value.first?.model
    }

    func updateStudyStatus(studyId: UUID, status: StudyStatus, submittedAt: Date?) async throws -> Study {
        let payload = UpdateStudyStatusPayload(status: status, submittedAt: submittedAt)
        let response: PostgrestResponse<StudyRow> = try await client
            .from("studies")
            .update(payload)
            .eq("id", value: studyId)
            .single()
            .execute()
        return response.value.model
    }

    func updateStudyNotes(studyId: UUID, notes: String?) async throws -> Study {
        let payload = UpdateStudyNotesPayload(notes: notes)
        let response: PostgrestResponse<StudyRow> = try await client
            .from("studies")
            .update(payload)
            .eq("id", value: studyId)
            .single()
            .execute()
        return response.value.model
    }

    func insertMedia(_ payload: NewMediaRequest) async throws -> Media {
        let response: PostgrestResponse<MediaRow> = try await client
            .from("media")
            .insert(payload, returning: .representation)
            .single()
            .execute()

        return response.value.model
    }

    func insertFeedback(_ payload: NewFeedbackRequest) async throws -> Feedback {
        let response: PostgrestResponse<FeedbackRow> = try await client
            .from("feedback")
            .insert(payload, returning: .representation)
            .single()
            .execute()
        return response.value.model
    }

    func upsertSignoff(_ payload: UpsertSignoffRequest) async throws -> Signoff {
        let response: PostgrestResponse<SignoffRow> = try await client
            .from("signoffs")
            .upsert(payload, onConflict: "study_id", returning: .representation, ignoreDuplicates: false)
            .single()
            .execute()
        return response.value.model
    }
}

// MARK: - Request Payloads

struct NewStudyRequest: Encodable, Sendable {
    let id: UUID
    let institutionId: UUID
    let createdBy: UUID
    let examType: String
    let status: StudyStatus
    let notes: String?

    init(
        id: UUID = UUID(),
        institutionId: UUID,
        createdBy: UUID,
        examType: String,
        status: StudyStatus,
        notes: String? = nil
    ) {
        self.id = id
        self.institutionId = institutionId
        self.createdBy = createdBy
        self.examType = examType
        self.status = status
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case institutionId = "institution_id"
        case createdBy = "created_by"
        case examType = "exam_type"
        case status
        case notes
    }
}

struct UpdateStudyStatusPayload: Encodable {
    let status: StudyStatus
    let submittedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case status
        case submittedAt = "submitted_at"
    }
}

struct UpdateStudyNotesPayload: Encodable {
    let notes: String?

    private enum CodingKeys: String, CodingKey {
        case notes
    }
}

struct NewMediaRequest: Encodable, Sendable {
    let id: UUID
    let studyId: UUID
    let kind: MediaKind
    let storagePath: String
    let contentType: String
    let durationSec: Double?
    let width: Int?
    let height: Int?
    let sha256: String?
    let status: MediaStatus

    init(
        id: UUID = UUID(),
        studyId: UUID,
        kind: MediaKind,
        storagePath: String,
        contentType: String,
        durationSec: Double? = nil,
        width: Int? = nil,
        height: Int? = nil,
        sha256: String? = nil,
        status: MediaStatus = .pending
    ) {
        self.id = id
        self.studyId = studyId
        self.kind = kind
        self.storagePath = storagePath
        self.contentType = contentType
        self.durationSec = durationSec
        self.width = width
        self.height = height
        self.sha256 = sha256
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case studyId = "study_id"
        case kind
        case storagePath = "storage_path"
        case contentType = "content_type"
        case durationSec = "duration_sec"
        case width
        case height
        case sha256
        case status
    }
}

struct NewFeedbackRequest: Encodable, Sendable {
    let id: UUID
    let studyId: UUID
    let reviewerId: UUID
    let rating: Int?
    let comments: String?

    init(
        id: UUID = UUID(),
        studyId: UUID,
        reviewerId: UUID,
        rating: Int? = nil,
        comments: String? = nil
    ) {
        self.id = id
        self.studyId = studyId
        self.reviewerId = reviewerId
        self.rating = rating
        self.comments = comments
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case studyId = "study_id"
        case reviewerId = "reviewer_id"
        case rating
        case comments
    }
}

struct UpsertSignoffRequest: Encodable, Sendable {
    let id: UUID
    let studyId: UUID
    let attendingId: UUID
    let status: SignoffStatus
    let signedAt: Date?

    init(
        id: UUID = UUID(),
        studyId: UUID,
        attendingId: UUID,
        status: SignoffStatus,
        signedAt: Date?
    ) {
        self.id = id
        self.studyId = studyId
        self.attendingId = attendingId
        self.status = status
        self.signedAt = signedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case studyId = "study_id"
        case attendingId = "attending_id"
        case status
        case signedAt = "signed_at"
    }
}

// MARK: - Row Decoders

private struct StudyRow: Decodable {
    let id: UUID
    let institution_id: UUID
    let created_by: UUID
    let exam_type: String
    let status: StudyStatus
    let submitted_at: Date?
    let notes: String?
    let created_at: Date

    var model: Study {
        Study(
            id: id,
            institutionId: institution_id,
            createdBy: created_by,
            examType: exam_type,
            status: status,
            submittedAt: submitted_at,
            notes: notes,
            createdAt: created_at
        )
    }
}

private struct MediaRow: Decodable {
    let id: UUID
    let study_id: UUID
    let kind: MediaKind
    let storage_path: String
    let content_type: String
    let duration_sec: Double?
    let width: Int?
    let height: Int?
    let sha256: String?
    let status: MediaStatus
    let created_at: Date

    var model: Media {
        Media(
            id: id,
            studyId: study_id,
            kind: kind,
            storagePath: storage_path,
            contentType: content_type,
            durationSec: duration_sec,
            width: width,
            height: height,
            sha256: sha256,
            status: status,
            createdAt: created_at
        )
    }
}

private struct FeedbackRow: Decodable {
    let id: UUID
    let study_id: UUID
    let reviewer_id: UUID
    let rating: Int?
    let comments: String?
    let created_at: Date

    var model: Feedback {
        Feedback(
            id: id,
            studyId: study_id,
            reviewerId: reviewer_id,
            rating: rating,
            comments: comments,
            createdAt: created_at
        )
    }
}

private struct SignoffRow: Decodable {
    let id: UUID
    let study_id: UUID
    let attending_id: UUID
    let status: SignoffStatus
    let signed_at: Date?

    var model: Signoff {
        Signoff(
            id: id,
            studyId: study_id,
            attendingId: attending_id,
            status: status,
            signedAt: signed_at
        )
    }
}
