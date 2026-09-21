import SwiftUI
import UIKit

@main
struct HomeSchoolHelperApp: App {
    @StateObject private var store = HomeschoolStore()

    var body: some Scene {
        WindowGroup {
            HomeTabView()
                .environmentObject(store)
                .tint(Sage.accent)
                #if DEBUG
                .preferredColorScheme(ProcessInfo.processInfo.environment["HSH_UI_TEST_DARK_MODE"] == "1" ? .dark : nil)
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
