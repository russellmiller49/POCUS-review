import Foundation
import Combine
import Supabase

protocol SupabaseClientProviding: Sendable {
    var client: SupabaseClient { get }
}

final class SupabaseClientManager: @unchecked Sendable, SupabaseClientProviding {
    static let shared = SupabaseClientManager(configuration: AppConfig.shared)

    let client: SupabaseClient

    init(configuration: AppConfig) {
        self.client = SupabaseClient(
            supabaseURL: configuration.supabase.apiURL,
            supabaseKey: configuration.supabase.anonKey
        )
    }
}
