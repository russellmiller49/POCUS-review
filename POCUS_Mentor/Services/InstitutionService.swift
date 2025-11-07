import Foundation
import Combine
import Supabase

protocol InstitutionServicing: Sendable {
    func fetchMemberships(for userId: UUID) async throws -> [MembershipWithInstitution]
    func fetchAllInstitutions() async throws -> [Institution]
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
            let institutionModel = Institution(
                id: institution.id,
                slug: institution.slug,
                name: institution.name,
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
            Institution(
                id: row.id,
                slug: row.slug,
                name: row.name,
                settings: row.settings ?? .null
            )
        }
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
