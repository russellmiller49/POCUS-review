import Foundation
import Supabase

protocol StorageServicing: Sendable {
    func signedURL(for path: String, expiresIn seconds: TimeInterval) async throws -> URL
}

struct SupabaseStorageService: StorageServicing {
    private let client: SupabaseClient
    private let bucket: String

    init(
        clientProvider: SupabaseClientProviding = SupabaseClientManager.shared,
        config: AppConfig = .shared
    ) {
        self.client = clientProvider.client
        self.bucket = config.supabase.bucket
    }

    func signedURL(for path: String, expiresIn seconds: TimeInterval) async throws -> URL {
        let expires = Int(seconds.rounded())
        let response = try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expires)

        guard let url = URL(string: response.signedURL) else {
            throw StorageServiceError.invalidURL
        }
        return url
    }
}

enum StorageServiceError: Error {
    case invalidURL
}
