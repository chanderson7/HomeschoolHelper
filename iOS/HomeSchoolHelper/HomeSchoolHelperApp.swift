import SwiftUI
import UIKit
import HomeschoolAuth

@main
struct HomeSchoolHelperApp: App {
    @StateObject private var auth = AuthStore(client: SupabaseConfiguration.makeClient())
    var body: some Scene {
        WindowGroup {
            AuthRootView()
                .environmentObject(auth)
                .tint(Sage.accent)
                .preferredColorScheme(.light)
                #if DEBUG
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if ProcessInfo.processInfo.environment["HSH_UI_TEST_LARGE_TEXT"] == "1" {
                        size = .accessibility3
                    }
                }
                #endif
        }
    }
}

enum Sage {
    // Keep accent-colored text readable on light backgrounds while retaining a
    // brighter green against dark surfaces.
    static let accent = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1)
        }
        return UIColor(red: 0.075, green: 0.424, blue: 0.220, alpha: 1)
    })
    static let soft = Color(uiColor: .secondarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}
