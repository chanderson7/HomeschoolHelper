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
        }
    }
}

enum Sage {
    static let accent = Color(uiColor: .systemGreen)
    static let soft = Color(uiColor: .secondarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}
