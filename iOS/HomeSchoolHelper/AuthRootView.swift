import SwiftUI
import HomeschoolCore
import HomeschoolAuth

struct AuthRootView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashCompleted = false
    @AppStorage("hsh_is_guest_mode") private var isGuestMode = false

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
        .onChange(of: auth.phase) { oldPhase, newPhase in
            if case .signedIn = newPhase {
                isGuestMode = false
            } else if case .signedIn = oldPhase, case .signedOut = newPhase {
                isGuestMode = false
            }
        }
    }

    @ViewBuilder private var protectedContent: some View {
        switch auth.phase {
        case .loading:
            SplashScreenView()
        case .signedOut:
            if isGuestMode {
                GuestSchoolView()
            } else {
                LoginView(onContinueAsGuest: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isGuestMode = true
                    }
                })
            }
        case .passwordRecovery:
            LoginView(recoveringPassword: true)
        case .signedIn(let identity):
            SignedInSchoolView(identity: identity).id(identity.id)
        }
    }
}

private struct GuestSchoolView: View {
    @StateObject private var store: HomeschoolStore

    init() {
        _store = StateObject(wrappedValue: HomeschoolStore(repository: JSONSchoolRepository(
            fileURL: HomeschoolStore.defaultFileURL()
        )))
    }

    var body: some View {
        HomeTabView()
            .environmentObject(store)
            .environment(\.signedInIdentity, nil)
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
        let accountURL = HomeschoolStore.accountFileURL(userID: identity.id)
        let defaultURL = HomeschoolStore.defaultFileURL()

        // One-time seamless migration: If account file does not exist yet on disk,
        // but local guest data exists at defaultURL, copy it so no records are lost.
        let fm = FileManager.default
        if !fm.fileExists(atPath: accountURL.path) && fm.fileExists(atPath: defaultURL.path) {
            try? fm.createDirectory(at: accountURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.copyItem(at: defaultURL, to: accountURL)
        }

        _store = StateObject(wrappedValue: HomeschoolStore(repository: JSONSchoolRepository(
            fileURL: accountURL
        )))
    }

    var body: some View {
        HomeTabView()
            .environmentObject(store)
            .environment(\.signedInIdentity, identity)
            .task {
                if store.state != SchoolState() {
                    cloudSync.scheduleAutoSync(state: store.state, userID: identity.id, client: auth.client)
                }
            }
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
