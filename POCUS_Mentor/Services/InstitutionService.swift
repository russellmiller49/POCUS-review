import Foundation
import Combine
import Supabase

protocol InstitutionServicing: Sendable {
    func fetchMemberships(for userId: UUID) async throws -> [MembershipWithInstitution]
    func fetchAllInstitutions() async throws -> [Institution]
    func fetchMembers(
        institutionId: UUID,
        roles: [MembershipRole]
    ) async throws -> [UserProfileSummary]
    func fetchProfile(userId: UUID) async throws -> UserProfileSummary?
    func createMembershipRequest(
        userId: UUID,
        institutionId: UUID,
        role: String,
        pgyYear: String?
    ) async throws
    func createProfile(userId: UUID, email: String, fullName: String) async throws
}

struct SupabaseInstitutionService: InstitutionServicing {
    private let clientProvider: SupabaseClientProviding

    init(clientProvider: SupabaseClientProviding = SupabaseClientManager.shared) {
        self.clientProvider = clientProvider
    }

    private var client: SupabaseClient { clientProvider.client }

    func fetchMemberships(for userId: UUID) async throws -> [MembershipWithInstitution] {
        let response: PostgrestResponse<[MembershipRow]> = try await client
            .from("memberships")
            .select(
                "user_id, institution_id, role, roles, institutions(id, slug, name, settings)"
            )
            .eq("user_id", value: userId)
            .eq("role_approved", value: true)
            .execute()

        return response.value.flatMap { row -> [MembershipWithInstitution] in
            guard let institution = row.institutions else { return [] }
            let override = InstitutionOverrides.override(for: institution.id)
            let institutionModel = Institution(
                id: institution.id,
                slug: override?.slug ?? institution.slug,
                name: override?.name ?? institution.name,
                settings: institution.settings ?? .null
            )

            // Use role column if available, otherwise fall back to roles array
            let roleToUse = row.role ?? row.roles.first ?? "fellow"
            let roles = row.roles.isEmpty ? [roleToUse] : row.roles

            return roles.map { roleString in
                let membership = Membership(
                    userId: row.userID,
                    institutionId: row.institutionID,
                    role: roleString
                )
                return MembershipWithInstitution(
                    membership: membership,
                    institution: institutionModel
                )
            }
        }
    }
    
    func fetchAllInstitutions() async throws -> [Institution] {
        let response: PostgrestResponse<[InstitutionRow]> = try await client
            .from("institutions")
            .select("id, slug, name, settings")
            .order("name")
            .execute()
        
        return response.value.map { row in
            let override = InstitutionOverrides.override(for: row.id)
            return Institution(
                id: row.id,
                slug: override?.slug ?? row.slug,
                name: override?.name ?? row.name,
                settings: row.settings ?? .null
            )
        }
    }

    func fetchMembers(
        institutionId: UUID,
        roles: [MembershipRole]
    ) async throws -> [UserProfileSummary] {
        guard !roles.isEmpty else { return [] }

        let allowed = Set(
            roles.flatMap { role -> [String] in
                if role == .administrator {
                    return [role.rawValue, "admin"]
                }
                return [role.rawValue]
            }
            .map { $0.lowercased() }
        )

        let response: PostgrestResponse<[InstitutionMemberRow]> = try await client
            .rpc(
                "list_institution_members",
                params: ListInstitutionMembersParams(target_institution: institutionId)
            )
            .execute()

        return response.value
            .filter { row in
                let roleStrings = row.allRoles.map { $0.lowercased() }
                return roleStrings.contains { allowed.contains($0) }
            }
            .map { row in
                UserProfileSummary(
                    id: row.user_id,
                    fullName: row.full_name,
                    email: row.email ?? ""
                )
            }
            .sorted {
                ($0.fullName ?? $0.email)
                    .localizedCaseInsensitiveCompare($1.fullName ?? $1.email) == .orderedAscending
            }
    }

    func fetchProfile(userId: UUID) async throws -> UserProfileSummary? {
        try await fetchProfiles(ids: [userId]).first?.summary
    }
    
    func createMembershipRequest(
        userId: UUID,
        institutionId: UUID,
        role: String,
        pgyYear: String?
    ) async throws {
        // Determine if role needs approval
        let needsApproval = role == "attending" || role == "admin"
        
        struct MembershipRequest: Encodable {
            let user_id: UUID
            let institution_id: UUID
            let role: String
            let pgy_year: String?
            let role_approved: Bool
            let role_requested_at: Date
        }
        
        let request = MembershipRequest(
            user_id: userId,
            institution_id: institutionId,
            role: role,
            pgy_year: pgyYear,
            role_approved: !needsApproval, // Fellows are auto-approved
            role_requested_at: Date()
        )
        
        try await client
            .from("memberships")
            .insert(request)
            .execute()
    }
    
    func createProfile(userId: UUID, email: String, fullName: String) async throws {
        struct ProfileRequest: Encodable {
            let id: UUID
            let email: String
            let full_name: String
        }
        
        let request = ProfileRequest(
            id: userId,
            email: email,
            full_name: fullName
        )
        
        try await client
            .from("profiles")
            .upsert(request, onConflict: "id")
            .execute()
    }
}

private struct InstitutionRow: Decodable {
    let id: UUID
    let slug: String
    let name: String
    let settings: JSONValue?
}

private struct MembershipRow: Decodable {
    let user_id: UUID
    let institution_id: UUID
    let role: String?
    let roles: [String]
    let institutions: InstitutionRow?

    var userID: UUID { user_id }
    var institutionID: UUID { institution_id }
}

private struct InstitutionMemberRow: Decodable {
    let user_id: UUID
    let full_name: String?
    let email: String?
    let role: String?
    let roles: [String]?

    var allRoles: [String] {
        var combined = roles ?? []
        if let role {
            combined.append(role)
        }
        return combined
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let email: String?
    let full_name: String?

    var summary: UserProfileSummary {
        UserProfileSummary(
            id: id,
            fullName: full_name,
            email: email ?? ""
        )
    }
}

private struct ListInstitutionMembersParams: Sendable {
    let target_institution: UUID
}
nonisolated extension ListInstitutionMembersParams: Encodable {}

private extension SupabaseInstitutionService {
    func fetchProfiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard !ids.isEmpty else { return [] }
        let response: PostgrestResponse<[ProfileRow]> = try await client
            .from("profiles")
            .select("id, full_name, email")
            .`in`("id", values: ids.map(\.uuidString))
            .execute()
        return response.value
    }
}

private enum InstitutionOverrides {
    private static let overrides: [UUID: (slug: String, name: String)] = {
        var map: [UUID: (slug: String, name: String)] = [:]
        if let naval = UUID(uuidString: "fd5043e9-9268-4b82-a703-88b18c8c0fd0") {
            map[naval] = (
                slug: "naval-medical-center-san-diego",
                name: "Naval Medical Center San Diego"
            )
        }
        if let ucsd = UUID(uuidString: "e5720023-40ae-432d-bd0c-c2602e912808") {
            map[ucsd] = (
                slug: "uc-san-diego-health",
                name: "UC San Diego Health"
            )
        }
        return map
    }()

    static func override(for id: UUID) -> (slug: String, name: String)? {
        overrides[id]
    }
}
