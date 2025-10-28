import Foundation
import Combine
import Supabase

protocol AuthServicing: Sendable {
    func sendLoginOTP(to email: String) async throws
    func verifyOTP(email: String, code: String) async throws -> AuthSession
    func currentSession() async throws -> Session?
    func currentUser() async throws -> SupabaseUserProfile?
    func signOut() async throws
}

struct SupabaseAuthService: AuthServicing {
    private let clientProvider: SupabaseClientProviding

    init(clientProvider: SupabaseClientProviding = SupabaseClientManager.shared) {
        self.clientProvider = clientProvider
    }

    private var client: SupabaseClient { clientProvider.client }

    func sendLoginOTP(to email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, code: String) async throws -> AuthSession {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .email
        )

        let user = response.user
        guard let session = response.session else {
            throw AuthError.missingSession
        }
        return AuthSession(
            profile: SupabaseUserProfile(
                id: user.id,
                email: user.email ?? email
            ),
            session: session
        )
    }

    func currentSession() async throws -> Session? {
        if let cached = client.auth.currentSession {
            return cached
        }
        return try? await client.auth.session
    }

    func currentUser() async throws -> SupabaseUserProfile? {
        if let current = client.auth.currentUser {
            return SupabaseUserProfile(id: current.id, email: current.email ?? "")
        }
        guard let user = try? await client.auth.user() else { return nil }
        return SupabaseUserProfile(id: user.id, email: user.email ?? "")
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

enum AuthError: Error {
    case missingSession
}

struct AuthSession: Sendable {
    let profile: SupabaseUserProfile
    let session: Session
}
