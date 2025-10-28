import Foundation
import Combine
import Supabase

protocol InstitutionServicing: Sendable {
    func fetchMemberships(for userId: UUID) async throws -> [MembershipWithInstitution]
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
                "user_id, institution_id, role, institutions(id, slug, name, settings)"
            )
            .eq("user_id", value: userId)
            .execute()

        return response.value.compactMap { row in
            guard let institution = row.institutions else { return nil }
            let membership = Membership(
                userId: row.userID,
                institutionId: row.institutionID,
                role: row.role
            )
            let institutionModel = Institution(
                id: institution.id,
                slug: institution.slug,
                name: institution.name,
                settings: institution.settings ?? .null
            )
            return MembershipWithInstitution(
                membership: membership,
                institution: institutionModel
            )
        }
    }
}

private struct MembershipRow: Decodable {
    let user_id: UUID
    let institution_id: UUID
    let role: String
    let institutions: InstitutionRow?

    var userID: UUID { user_id }
    var institutionID: UUID { institution_id }

    struct InstitutionRow: Decodable {
        let id: UUID
        let slug: String
        let name: String
        let settings: JSONValue?
    }
}
