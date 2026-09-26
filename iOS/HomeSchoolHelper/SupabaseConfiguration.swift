import Foundation
import Supabase

enum SupabaseConfiguration {
    // Publishable client key, not a server secret. Database RLS enforces access.
    static let projectURL = URL(string: "https://etzlarmryjtukopwfmru.supabase.co")!
    static let publishableKey = "sb_publishable_Ll7Spia4Xi8PDIlS1BzN0A__RIQntGi"
    static let universalCallbackURL = URL(string: "https://homeschoohelp.netlify.app/auth/callback")!
    static let customSchemeCallbackURL = URL(string: "homeschoolhelper://auth/callback")!

    static var callbackURL: URL {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_USE_CUSTOM_SCHEME_CALLBACK"] == "1" {
            return customSchemeCallbackURL
        }
        #endif
        return universalCallbackURL
    }

    static func makeClient() -> SupabaseClient {
        var storageKey = "homeschoolhelper-auth-v1"
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"], let id = UUID(uuidString: value) {
            storageKey += "-uitest-\(id.uuidString)"
        }
        #endif
        return SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: publishableKey,
            options: .init(auth: .init(
                redirectToURL: callbackURL,
                storageKey: storageKey,
                flowType: .pkce,
                emitLocalSessionAsInitialSession: false
            ))
        )
    }
}
