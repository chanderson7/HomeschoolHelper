import SwiftUI
import HomeschoolCore
import HomeschoolAuth

struct AuthRootView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashCompleted = false

    var body: some View {
        ZStack {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HSH_UI_TEST_AUTH_MODE"] == "authenticated",
               let raw = ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"], UUID(uuidString: raw) != nil {
                // Explicit UI fixture only: no backend/session or real household access.
                UITestSchoolView()
            } else if !splashCompleted && ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] == nil {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                protectedContent
            }
            #else
            if !splashCompleted {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                protectedContent
            }
            #endif
        }
        .task { await auth.start() }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"] != nil {
                splashCompleted = true
                return
            }
            #endif
            // Guarantee at least 3 seconds of splash branding
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                splashCompleted = true
            }
        }
        .onOpenURL { url in Task { await auth.handleCallback(url) } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await auth.refreshSession() } }
        }
    }

    @ViewBuilder private var protectedContent: some View {
        switch auth.phase {
        case .loading:
            SplashScreenView()
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
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: HomeschoolStore
    @ObservedObject private var cloudSync = CloudSyncManager.shared

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
            .onChange(of: store.state) { _, newState in
                cloudSync.scheduleAutoSync(state: newState, userID: identity.id, client: auth.client)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    Task {
                        await cloudSync.flushNow(state: store.state, userID: identity.id, client: auth.client)
                    }
                }
            }
    }
}

#if DEBUG
private struct UITestSchoolView: View {
    @StateObject private var store: HomeschoolStore

    init() {
        let store = HomeschoolStore()
        if ProcessInfo.processInfo.environment["HSH_LOAD_SAMPLE_HOUSEHOLD"] == "1" {
            _ = store.restore(SampleDataGenerator.generateSampleState())
        }
        _store = StateObject(wrappedValue: store)
    }

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
