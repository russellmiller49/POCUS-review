import Foundation
import Combine

enum StudyStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case submitted
    case reviewable
    case needsRevision = "needs_revision"
    case approved
    case signedOff = "signed_off"
}

enum MediaKind: String, Codable, CaseIterable, Sendable {
    case image
    case video
    case clip
    case other
}

enum MediaStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case uploading
    case clean
    case failed
}

enum SignoffStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case revisions
}

enum MembershipRole: String, Codable, CaseIterable, Sendable {
    case fellow
    case attending
    case administrator
    case admin

    var normalized: MembershipRole {
        switch self {
        case .admin:
            return .administrator
        default:
            return self
        }
    }

    var displayName: String {
        switch self.normalized {
        case .fellow:
            return "Fellow"
        case .attending:
            return "Attending"
        case .administrator:
            return "Admin"
        case .admin:
            return "Admin"
        }
    }
}

struct Institution: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let slug: String
    let name: String
    let settings: JSONValue
}

struct Membership: Identifiable, Codable, Hashable, Sendable {
    typealias ID = String
    var id: String { "\(userId.uuidString)_\(institutionId.uuidString)" }
    let userId: UUID
    let institutionId: UUID
    let role: String

    var membershipRole: MembershipRole {
        MembershipRole(rawValue: role.lowercased())?.normalized ?? .fellow
    }
}

struct Study: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let institutionId: UUID
    let createdBy: UUID
    let examType: String
    let status: StudyStatus
    let submittedAt: Date?
    let notes: String?
    let createdAt: Date
}

struct Media: Identifiable, Codable, Hashable, Sendable {
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
    let createdAt: Date
}

struct Feedback: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let studyId: UUID
    let reviewerId: UUID
    let rating: Int?
    let comments: String?
    let createdAt: Date
}

struct Signoff: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let studyId: UUID
    let attendingId: UUID
    let status: SignoffStatus
    let signedAt: Date?
}

struct MembershipWithInstitution: Identifiable, Sendable {
    typealias ID = String
    let membership: Membership
    let institution: Institution

    var id: String { membership.id }
}

/// Lightweight representation of the Supabase auth user.
struct SupabaseUserProfile: Identifiable, Sendable {
    let id: UUID
    let email: String
}

// MARK: - JSON Helper

/// Codable JSON catch-all type to safely round-trip settings payloads.
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .bool(let bool):
            try container.encode(bool)
        case .object(let dictionary):
            try container.encode(dictionary)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
}
