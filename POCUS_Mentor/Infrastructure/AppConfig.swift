import Foundation

enum AppConfigError: Error, LocalizedError {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing required configuration value for \(key)"
        case .invalidURL(let key):
            return "Invalid URL provided for \(key)"
        }
    }
}

struct SupabaseConfiguration: Sendable {
    let apiURL: URL
    let anonKey: String
    let storageHost: URL
    let bucket: String

    var resumableUploadEndpoint: URL {
        storageHost.appendingPathComponent("storage/v1/upload/resumable")
    }
}

struct AppConfig: Sendable {
    let supabase: SupabaseConfiguration
    let uploadChunkSize: Int = 6 * 1024 * 1024

    static let shared: AppConfig = {
        do {
            return try AppConfig(bundle: .main)
        } catch {
            fatalError("Failed to load AppConfig: \(error)")
        }
    }()

    init(bundle: Bundle) throws {
        self.supabase = try SupabaseConfiguration(bundle: bundle)
    }
}

private extension SupabaseConfiguration {
    init(bundle: Bundle) throws {
        // Hardcode the values directly since Build Settings aren't working
        let urlString = "https://tqnhxlwvkkswuckszlee.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRxbmh4bHd2a2tzd3Vja3N6bGVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0NTg0MDQsImV4cCI6MjA3NTAzNDQwNH0.k76NI2Ji5gQSF3gBvmZ0yU1ZtdORv21zD_ZhJSGze4A"
        let storageHostString = "https://tqnhxlwvkkswuckszlee.storage.supabase.co"
        let bucket = "pocus-media"

        guard let url = URL(string: urlString) else {
            throw AppConfigError.invalidURL("SUPABASE_URL")
        }
        guard let storageHost = URL(string: storageHostString) else {
            throw AppConfigError.invalidURL("SUPABASE_STORAGE_HOST")
        }

        self.init(apiURL: url, anonKey: anonKey, storageHost: storageHost, bucket: bucket)
    }
}

private extension Bundle {
    func value<T>(forInfoKey key: String) throws -> T {
        guard let value = object(forInfoDictionaryKey: key) as? T else {
            throw AppConfigError.missingValue(key)
        }
        return value
    }
}
