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
        
        // Supabase Swift SDK v2.36.0+ returns a SignedURLOutput struct with a signedURL property (String)
        // Use Mirror reflection to safely access the signedURL property
        let mirror = Mirror(reflecting: response)
        
        guard let signedURLProperty = mirror.children.first(where: { $0.label == "signedURL" }),
              let urlString = signedURLProperty.value as? String,
              let url = URL(string: urlString) else {
            throw StorageServiceError.invalidURL
        }
        
        return url
    }
}

enum StorageServiceError: Error {
    case invalidURL
}
