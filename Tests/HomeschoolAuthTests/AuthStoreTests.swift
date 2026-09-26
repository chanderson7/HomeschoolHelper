import Supabase
import XCTest
@testable import HomeschoolAuth

final class AuthStoreTests: XCTestCase {
    @MainActor
    func testCachedSessionStaysLoadingUntilRemoteVerificationFinishes() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: true, verifiedIdentity: identity, pauseRefresh: true)
        let store = AuthStore(client: testClient(), driver: driver)

        let start = Task { await store.start() }
        await driver.waitUntilRefreshStarts()

        XCTAssertEqual(store.phase, .loading)
        await driver.resumeRefresh()
        await start.value

        XCTAssertEqual(store.phase, .signedIn(identity))
    }

    @MainActor
    func testUnverifiedCachedSessionFailsClosedWithoutClearingItOnNetworkFailure() async {
        let driver = AuthDriver(hasStoredSession: true, refreshError: TestError.offline)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.start()

        XCTAssertEqual(store.phase, .signedOut)
        let localClearCount = await driver.localClearCount()
        XCTAssertEqual(localClearCount, 0)
    }

    @MainActor
    func testRecoveryCallbackNeverEntersAppUntilPasswordUpdateSucceeds() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: false, verifiedIdentity: identity)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.handleCallback(URL(string: "homeschoolhelper://auth/recovery?code=abc")!)

        XCTAssertEqual(store.phase, .passwordRecovery(identity))
        let initialUpdateCount = await driver.updatePasswordCount()
        XCTAssertEqual(initialUpdateCount, 0)

        await store.updatePassword(password: "New-password-123")
        XCTAssertEqual(store.phase, .signedIn(identity))
        let finalUpdateCount = await driver.updatePasswordCount()
        XCTAssertEqual(finalUpdateCount, 1)
    }

    @MainActor
    func testConfirmationCallbackExchangesThenEntersVerifiedSession() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: false, verifiedIdentity: identity)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.handleCallback(URL(string: "homeschoolhelper://auth/callback?code=abc")!)

        XCTAssertEqual(store.phase, .signedIn(identity))
        let exchangeCount = await driver.callbackExchangeCount()
        XCTAssertEqual(exchangeCount, 1)
    }

    @MainActor
    func testDeleteAccountPurgesSessionAndClearsLocalCredentials() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: true, verifiedIdentity: identity)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.start()
        XCTAssertEqual(store.phase, .signedIn(identity))

        await store.deleteAccount()
        XCTAssertEqual(store.phase, .signedOut)

        let deleteCount = await driver.remoteDeleteCount()
        let clearCount = await driver.localClearCount()
        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(clearCount, 1)
    }

    @MainActor
    func testHostileCallbackIsDeniedWithoutCodeExchange() async {
        let driver = AuthDriver(hasStoredSession: false)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.handleCallback(URL(string: "homeschoolhelper://evil/callback?code=abc")!)

        XCTAssertEqual(store.phase, .loading)
        XCTAssertEqual(store.errorMessage, "That sign-in link is not valid for this app.")
        let exchangeCount = await driver.callbackExchangeCount()
        XCTAssertEqual(exchangeCount, 0)
    }

    @MainActor
    func testUniversalLinkConfirmationCallbackExchangesThenEntersVerifiedSession() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: false, verifiedIdentity: identity)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.handleCallback(URL(string: "https://homeschoohelp.netlify.app/auth/callback?code=univ-code-123")!)

        XCTAssertEqual(store.phase, .signedIn(identity))
        let exchangeCount = await driver.callbackExchangeCount()
        XCTAssertEqual(exchangeCount, 1)
    }

    @MainActor
    func testUniversalLinkRecoveryCallbackExchangesThenTransitionsToPasswordRecovery() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: false, verifiedIdentity: identity)
        let store = AuthStore(client: testClient(), driver: driver)

        await store.handleCallback(URL(string: "https://homeschoohelp.netlify.app/auth/recovery?code=univ-rec-456")!)

        XCTAssertEqual(store.phase, .passwordRecovery(identity))
        let exchangeCount = await driver.callbackExchangeCount()
        XCTAssertEqual(exchangeCount, 1)
    }

    @MainActor
    func testHostileUniversalLinkIsDeniedWithoutCodeExchange() async {
        let driver = AuthDriver(hasStoredSession: false)
        let store = AuthStore(client: testClient(), driver: driver)

        // Invalid host
        await store.handleCallback(URL(string: "https://evil.netlify.app/auth/callback?code=abc")!)
        XCTAssertEqual(store.phase, .loading)
        XCTAssertEqual(store.errorMessage, "That sign-in link is not valid for this app.")

        // Invalid path on valid host
        await store.handleCallback(URL(string: "https://homeschoohelp.netlify.app/api/hijack?code=abc")!)
        XCTAssertEqual(store.phase, .loading)
        XCTAssertEqual(store.errorMessage, "That sign-in link is not valid for this app.")

        let exchangeCount = await driver.callbackExchangeCount()
        XCTAssertEqual(exchangeCount, 0)
    }

    @MainActor
    func testSignOutWinsOverLateSignInResponse() async {
        let identity = AuthIdentity(id: UUID(), email: "parent@example.com")
        let driver = AuthDriver(hasStoredSession: false, verifiedIdentity: identity, pauseSignIn: true)
        let store = AuthStore(client: testClient(), driver: driver)

        let signIn = Task { await store.signIn(email: identity.email, password: "password") }
        await driver.waitUntilSignInStarts()
        await store.signOut()
        await driver.resumeSignIn()
        await signIn.value

        XCTAssertEqual(store.phase, .signedOut)
        let localClearCount = await driver.localClearCount()
        XCTAssertGreaterThanOrEqual(localClearCount, 1)
    }

    private func testClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "test-key"
        )
    }
}

private enum TestError: Error {
    case offline
}

private actor AuthDriver: AuthClientDriving {
    private let stream: AsyncStream<AuthDriverEvent>
    private let continuation: AsyncStream<AuthDriverEvent>.Continuation
    private let storedSession: Bool
    private let verifiedIdentity: AuthIdentity
    private let refreshError: Error?
    private let pauseRefresh: Bool
    private let pauseSignIn: Bool
    private var refreshContinuation: CheckedContinuation<Void, Never>?
    private var refreshStarted = false
    private var signInContinuation: CheckedContinuation<Void, Never>?
    private var signInStarted = false
    private var localClears = 0
    private var remoteDeletes = 0
    private var passwordUpdates = 0
    private var callbackExchanges = 0

    init(
        hasStoredSession: Bool,
        verifiedIdentity: AuthIdentity = AuthIdentity(id: UUID(), email: "test@example.com"),
        refreshError: Error? = nil,
        pauseRefresh: Bool = false,
        pauseSignIn: Bool = false
    ) {
        let pair = AsyncStream<AuthDriverEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
        storedSession = hasStoredSession
        self.verifiedIdentity = verifiedIdentity
        self.refreshError = refreshError
        self.pauseRefresh = pauseRefresh
        self.pauseSignIn = pauseSignIn
    }

    var events: AsyncStream<AuthDriverEvent> { stream }
    func hasStoredSession() -> Bool { storedSession }

    func refreshStoredSession() async throws {
        refreshStarted = true
        if pauseRefresh {
            await withCheckedContinuation { refreshContinuation = $0 }
        }
        if let refreshError { throw refreshError }
    }

    func verifiedUser() async throws -> AuthIdentity { verifiedIdentity }

    func signIn(email: String, password: String) async throws {
        signInStarted = true
        if pauseSignIn {
            await withCheckedContinuation { signInContinuation = $0 }
        }
    }

    func signUp(email: String, password: String) async throws -> Bool { false }
    func sendPasswordReset(email: String, redirectTo: URL) async throws {}
    func updatePassword(_ password: String) async throws { passwordUpdates += 1 }
    func signOutRemotely() async throws {}
    func deleteUserRemotely() async throws { remoteDeletes += 1 }
    func clearLocalSession() async throws { localClears += 1 }
    func exchangeCallbackCode(_ code: String) async throws { callbackExchanges += 1 }

    func waitUntilRefreshStarts() async {
        while !refreshStarted { await Task.yield() }
    }

    func resumeRefresh() { refreshContinuation?.resume(); refreshContinuation = nil }

    func waitUntilSignInStarts() async {
        while !signInStarted { await Task.yield() }
    }

    func resumeSignIn() { signInContinuation?.resume(); signInContinuation = nil }
    func localClearCount() -> Int { localClears }
    func remoteDeleteCount() -> Int { remoteDeletes }
    func updatePasswordCount() -> Int { passwordUpdates }
    func callbackExchangeCount() -> Int { callbackExchanges }
}
