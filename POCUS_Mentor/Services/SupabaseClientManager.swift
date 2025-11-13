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
        #if !os(Linux) && !os(Android)
        let options = SupabaseClientOptions()
        #else
        let options = SupabaseClientOptions(
            db: .init(),
            auth: .init(storage: AuthClient.Configuration.defaultLocalStorage),
            global: .init(),
            functions: .init(),
            realtime: .init(),
            storage: .init()
        )
        #endif

        self.client = SupabaseClient(
            supabaseURL: configuration.supabase.apiURL,
            supabaseKey: configuration.supabase.anonKey,
            options: options
        )
    }
}
