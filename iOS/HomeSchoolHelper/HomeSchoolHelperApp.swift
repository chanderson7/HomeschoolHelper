import SwiftUI
import UIKit
import HomeschoolAuth

@main
struct HomeSchoolHelperApp: App {
    @StateObject private var auth = AuthStore(client: SupabaseConfiguration.makeClient())
    @AppStorage("app_appearance") private var appearancePreference: String = "system"

    private var colorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HSH_UI_TEST_DARK_MODE"] == "1" {
            return .dark
        }
        #endif
        switch appearancePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            AuthRootView()
                .environmentObject(auth)
                .tint(Sage.accent)
                .preferredColorScheme(colorScheme)
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
    static let accent = Color(uiColor: .systemGreen)
    static let soft = Color(uiColor: .secondarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}
