import SwiftUI
import HomeschoolCore
import HomeschoolAuth

struct AuthRootView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HSH_UI_TEST_AUTH_MODE"] == "authenticated",
               let raw = ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"], UUID(uuidString: raw) != nil {
                // Explicit UI fixture only: no backend/session or real household access.
                UITestSchoolView()
            } else {
                protectedContent
            }
            #else
            protectedContent
            #endif
        }
        .task { await auth.start() }
        .onOpenURL { url in Task { await auth.handleCallback(url) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await auth.refreshSession() } }
        }
    }

    @ViewBuilder private var protectedContent: some View {
        switch auth.phase {
        case .loading:
            ProgressView("Checking your account…").accessibilityIdentifier("authLoading")
        case .signedOut:
            LoginView()
        case .passwordRecovery:
            LoginView(recoveringPassword: true)
        case .signedIn(let identity):
            SignedInSchoolView(identity: identity).id(identity.id)
        }
    }
}

private struct SignedInSchoolView: View {
    let identity: AuthIdentity
    @StateObject private var store: HomeschoolStore

    init(identity: AuthIdentity) {
        self.identity = identity
        _store = StateObject(wrappedValue: HomeschoolStore(repository: JSONSchoolRepository(
            fileURL: HomeschoolStore.accountFileURL(userID: identity.id)
        )))
    }

    var body: some View {
        HomeTabView()
            .environmentObject(store)
            .environment(\.signedInIdentity, identity)
    }
}

#if DEBUG
private struct UITestSchoolView: View {
    @StateObject private var store = HomeschoolStore()
    var body: some View { HomeTabView().environmentObject(store) }
}
#endif

private struct SignedInIdentityKey: EnvironmentKey {
    static let defaultValue: AuthIdentity? = nil
}

extension EnvironmentValues {
    var signedInIdentity: AuthIdentity? {
        get { self[SignedInIdentityKey.self] }
        set { self[SignedInIdentityKey.self] = newValue }
    }
}
