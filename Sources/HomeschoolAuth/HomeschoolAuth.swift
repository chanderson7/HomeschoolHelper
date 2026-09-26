import Combine
import Foundation
import Supabase

/// The small, app-safe portion of a Supabase user record exposed to the UI.
public struct AuthIdentity: Equatable, Sendable {
    public let id: UUID
    public let email: String

    public init(id: UUID, email: String) {
        self.id = id
        self.email = email
    }
}

/// The only authentication states the application is allowed to render.
public enum AuthPhase: Equatable {
    case loading
    case signedOut
    case signedIn(AuthIdentity)
    case passwordRecovery(AuthIdentity)
}

/// Internal boundary that keeps state-machine tests independent of Supabase and
/// makes the production adapter the only place that touches SDK session objects.
enum AuthDriverEvent: Equatable {
    case signedIn
    case signedOut
    case tokenRefreshed
    case passwordRecovery(AuthIdentity?)
}

protocol AuthClientDriving: AnyObject {
    var events: AsyncStream<AuthDriverEvent> { get async }
    func hasStoredSession() async -> Bool
    func refreshStoredSession() async throws
    func verifiedUser() async throws -> AuthIdentity
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws -> Bool
    func sendPasswordReset(email: String, redirectTo: URL) async throws
    func updatePassword(_ password: String) async throws
    func signOutRemotely() async throws
    func deleteUserRemotely() async throws
    func clearLocalSession() async throws
    func exchangeCallbackCode(_ code: String) async throws
}

private final class SupabaseAuthDriver: AuthClientDriving {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var events: AsyncStream<AuthDriverEvent> {
        let source = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in source {
                    let identity = session.map { AuthIdentity(id: $0.user.id, email: $0.user.email ?? "") }
                    switch event {
                    case .signedIn: continuation.yield(.signedIn)
                    case .signedOut: continuation.yield(.signedOut)
                    case .tokenRefreshed: continuation.yield(.tokenRefreshed)
                    case .passwordRecovery: continuation.yield(.passwordRecovery(identity))
                    default: break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func hasStoredSession() async -> Bool { client.auth.currentSession != nil }
    func refreshStoredSession() async throws { _ = try await client.auth.refreshSession() }
    func verifiedUser() async throws -> AuthIdentity {
        let user = try await client.auth.user()
        return AuthIdentity(id: user.id, email: user.email ?? "")
    }
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(email: email, password: password)
        return response.session != nil
    }
    func sendPasswordReset(email: String, redirectTo: URL) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo)
    }
    func updatePassword(_ password: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: password))
    }
    func signOutRemotely() async throws { try await client.auth.signOut() }
    func deleteUserRemotely() async throws {
        _ = try await client.rpc("delete_user_account").execute()
    }
    func clearLocalSession() async throws { try await client.auth.signOut(scope: .local) }
    func exchangeCallbackCode(_ code: String) async throws {
        _ = try await client.auth.exchangeCodeForSession(authCode: code)
    }
}

/// Owns the UI-facing authentication state for HomeSchool Helper.
///
/// A session found in Supabase's Keychain storage is deliberately never enough to
/// enter the app. `start()` and `refreshSession()` both validate it with
/// `auth.user()`, which asks the Auth server to validate the access token.
@MainActor
public final class AuthStore: ObservableObject {
    public let client: SupabaseClient

    @Published public private(set) var phase: AuthPhase = .loading
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var notice: String?
    @Published public private(set) var isBusy = false

    private var authEventsTask: Task<Void, Never>?
    private var sessionValidationTask: Task<Void, Never>?
    private var operationGeneration = 0
    private var ignoresLateSessionEvents = false
    private var recoveryIdentity: AuthIdentity?
    private var isRecoveringCallback = false

    public init(client: SupabaseClient) {
        self.client = client
        driver = SupabaseAuthDriver(client: client)
    }

    init(client: SupabaseClient, driver: AuthClientDriving) {
        self.client = client
        self.driver = driver
    }

    private let driver: AuthClientDriving

    deinit {
        authEventsTask?.cancel()
    }

    /// Starts event observation and validates any Keychain-backed session remotely.
    public func start() async {
        observeAuthEventsIfNeeded()
        await validateSessionIfNeeded()
    }

    /// Revalidates a stored session. A connectivity failure fails closed but does
    /// not erase the SDK's stored session, so the user can retry after reconnecting.
    public func refreshSession() async {
        await validateSessionIfNeeded()
    }

    /// Clears transient status text after the UI has presented it.
    public func clearMessages() {
        errorMessage = nil
        notice = nil
    }

    public func signIn(email: String, password: String) async {
        let generation = beginOperation()
        ignoresLateSessionEvents = false
        isRecoveringCallback = false
        recoveryIdentity = nil

        do {
            try await driver.signIn(email: normalized(email), password: password)
            guard isCurrent(generation) else {
                await clearLateSessionIfNeeded()
                return
            }
            try await verifyAndAdoptSession(generation: generation)
        } catch {
            failClosed(error, generation: generation)
        }
    }

    public func signUp(email: String, password: String) async {
        let generation = beginOperation()
        ignoresLateSessionEvents = false
        isRecoveringCallback = false
        recoveryIdentity = nil

        do {
            let hasSession = try await driver.signUp(email: normalized(email), password: password)

            guard isCurrent(generation) else {
                await clearLateSessionIfNeeded()
                return
            }

            // With email confirmation enabled Supabase intentionally returns no
            // session. Do not treat that as an authenticated app session.
            guard hasSession else {
                phase = .signedOut
                notice = "Check your email to confirm your account, then sign in."
                isBusy = false
                return
            }
            try await verifyAndAdoptSession(generation: generation)
        } catch {
            failClosed(error, generation: generation)
        }
    }

    public func sendPasswordReset(email: String) async {
        let generation = beginOperation()

        do {
            try await driver.sendPasswordReset(
                email: normalized(email),
                redirectTo: Self.recoveryCallbackURL
            )
            guard isCurrent(generation) else { return }
            phase = .signedOut
            notice = "If an account exists for that email, a password-reset link is on its way."
            isBusy = false
        } catch {
            failClosed(error, generation: generation)
        }
    }

    /// Updates a password only for a verified recovery flow, then unlocks the app.
    public func updatePassword(password: String) async {
        guard case .passwordRecovery = phase else {
            errorMessage = "Open a password-reset link before choosing a new password."
            return
        }

        let generation = beginOperation()
        do {
            try await driver.updatePassword(password)
            guard isCurrent(generation) else { return }
            let identity = try await driver.verifiedUser()
            guard isCurrent(generation) else { return }
            recoveryIdentity = nil
            isRecoveringCallback = false
            phase = .signedIn(identity)
            errorMessage = nil
            isBusy = false
            notice = "Your password has been updated."
        } catch {
            // Keep the recovery screen available when an update fails.
            guard isCurrent(generation) else { return }
            isBusy = false
            errorMessage = message(for: error)
        }
    }

    /// Signs out remotely when possible and always attempts a local Keychain clear.
    /// UI access is revoked before either request returns, so a slow or failed
    /// network sign-out cannot leave protected content on screen.
    public func signOut() async {
        operationGeneration &+= 1
        let generation = operationGeneration
        ignoresLateSessionEvents = true
        isRecoveringCallback = false
        recoveryIdentity = nil
        phase = .signedOut
        errorMessage = nil
        notice = nil
        isBusy = true

        var remoteError: Error?
        do {
            try await driver.signOutRemotely()
        } catch {
            remoteError = error
        }

        // A remote error must not retain credentials in the local Keychain.
        do {
            try await driver.clearLocalSession()
        } catch {
            if remoteError == nil {
                remoteError = error
            }
        }

        guard isCurrent(generation) else { return }
        isBusy = false
        if let remoteError {
            errorMessage = "Signed out on this device. The server could not be reached to revoke the session."
        }
    }

    /// Permanently deletes the user's remote account and clears local credentials.
    /// UI access is revoked immediately to prevent lingering access.
    public func deleteAccount() async {
        operationGeneration &+= 1
        let generation = operationGeneration
        ignoresLateSessionEvents = true
        isRecoveringCallback = false
        recoveryIdentity = nil
        phase = .signedOut
        errorMessage = nil
        notice = nil
        isBusy = true

        var remoteError: Error?
        do {
            try await driver.deleteUserRemotely()
        } catch {
            remoteError = error
        }

        // Even if remote RPC fails or user was already purged, always clear local Keychain session.
        do {
            try await driver.clearLocalSession()
        } catch {
            if remoteError == nil {
                remoteError = error
            }
        }

        guard isCurrent(generation) else { return }
        isBusy = false
        if let remoteError {
            errorMessage = "Account deleted on this device. The server could not be reached to confirm remote deletion."
        }
    }

    /// Accepts only the app's registered PKCE callback URLs and exchanges its code.
    public func handleCallback(_ url: URL) async {
        guard let kind = callbackKind(for: url),
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value,
              !code.isEmpty
        else {
            errorMessage = "That sign-in link is not valid for this app."
            return
        }

        let generation = beginOperation()
        ignoresLateSessionEvents = false
        isRecoveringCallback = kind == .recovery
        do {
            try await driver.exchangeCallbackCode(code)
            guard isCurrent(generation) else {
                await clearLateSessionIfNeeded()
                return
            }
            let user = try await driver.verifiedUser()
            guard isCurrent(generation) else { return }
            switch kind {
            case .recovery:
                recoveryIdentity = user
                isRecoveringCallback = false
                phase = .passwordRecovery(user)
                notice = "Choose a new password to finish resetting your account."
            case .confirmation:
                recoveryIdentity = nil
                isRecoveringCallback = false
                phase = .signedIn(user)
                notice = "Your account is confirmed."
            }
            isBusy = false
        } catch {
            isRecoveringCallback = false
            failClosed(error, generation: generation)
        }
    }

    private static let recoveryCallbackURL = URL(string: "homeschoolhelper://auth/recovery")!

    private func observeAuthEventsIfNeeded() {
        guard authEventsTask == nil else { return }
        authEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in await self.driver.events {
                guard !Task.isCancelled else { return }
                await self.handleAuthEvent(event)
            }
        }
    }

    private func handleAuthEvent(_ event: AuthDriverEvent) async {
        switch event {
        case .signedOut:
            operationGeneration &+= 1
            recoveryIdentity = nil
            phase = .signedOut
            isBusy = false
        case .passwordRecovery:
            guard !ignoresLateSessionEvents else { return }
            isRecoveringCallback = true
            let generation = operationGeneration
            do {
                let user = try await driver.verifiedUser()
                guard isCurrent(generation), !ignoresLateSessionEvents else { return }
                recoveryIdentity = user
                isRecoveringCallback = false
                phase = .passwordRecovery(user)
                errorMessage = nil
                isBusy = false
            } catch {
                isRecoveringCallback = false
                failClosed(error, generation: generation)
            }
        case .signedIn, .tokenRefreshed:
            guard !ignoresLateSessionEvents else {
                await clearLateSessionIfNeeded()
                return
            }
            guard recoveryIdentity == nil, !isRecoveringCallback, sessionValidationTask == nil else { return }
            let generation = operationGeneration
            do {
                try await verifyAndAdoptSession(generation: generation)
            } catch {
                failClosed(error, generation: generation)
            }
        }
    }

    private func validateStoredSession(generation: Int) async {
        // This reads the SDK's default secure Keychain storage but does not
        // authorize the UI. The following refresh and user request are remote.
        guard await driver.hasStoredSession() else {
            guard isCurrent(generation) else { return }
            if let recoveryIdentity {
                phase = .passwordRecovery(recoveryIdentity)
                isBusy = false
                return
            }
            phase = .signedOut
            isBusy = false
            return
        }

        do {
            try await driver.refreshStoredSession()
            guard isCurrent(generation) else { return }
            try await verifyAndAdoptSession(generation: generation)
        } catch {
            if let recoveryIdentity, isCurrent(generation) {
                phase = .passwordRecovery(recoveryIdentity)
                isBusy = false
                errorMessage = message(for: error)
                return
            }
            failClosed(error, generation: generation)
        }
    }

    private func validateSessionIfNeeded() async {
        if let sessionValidationTask {
            await sessionValidationTask.value
            return
        }

        let generation = beginOperation()
        ignoresLateSessionEvents = false
        if recoveryIdentity == nil {
            phase = .loading
        } else {
            phase = .passwordRecovery(recoveryIdentity!)
        }
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.validateStoredSession(generation: generation)
        }
        sessionValidationTask = task
        await task.value
        sessionValidationTask = nil
    }

    private func verifyAndAdoptSession(generation: Int) async throws {
        // `user()` validates the current access token on the Auth server.
        let user = try await driver.verifiedUser()
        guard isCurrent(generation), !ignoresLateSessionEvents else { return }
        if let recoveryIdentity {
            phase = .passwordRecovery(recoveryIdentity)
            isBusy = false
            return
        }
        guard !isRecoveringCallback else { return }
        phase = .signedIn(user)
        errorMessage = nil
        isBusy = false
    }

    private func beginOperation() -> Int {
        operationGeneration &+= 1
        errorMessage = nil
        notice = nil
        isBusy = true
        return operationGeneration
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == operationGeneration
    }

    private func clearLateSessionIfNeeded() async {
        guard ignoresLateSessionEvents else { return }
        try? await driver.clearLocalSession()
    }

    private func failClosed(_ error: Error, generation: Int) {
        guard isCurrent(generation) else { return }
        phase = .signedOut
        isBusy = false
        errorMessage = message(for: error)
    }

    private enum CallbackKind: Equatable {
        case confirmation
        case recovery
    }

    private func callbackKind(for url: URL) -> CallbackKind? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        guard components.port == nil,
              components.user == nil,
              components.password == nil
        else {
            return nil
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.lowercased()

        if scheme == "homeschoolhelper" && host == "auth" {
            switch path {
            case "/callback", "callback": return .confirmation
            case "/recovery", "recovery": return .recovery
            default: return nil
            }
        } else if scheme == "https" && host == "homeschoohelp.netlify.app" {
            switch path {
            case "/auth/callback", "auth/callback": return .confirmation
            case "/auth/recovery", "auth/recovery": return .recovery
            default: return nil
            }
        } else {
            return nil
        }
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func message(for error: Error) -> String {
        // Auth errors can contain implementation and server detail. Keep the UI
        // actionable without exposing those details or credentials.
        let text = (error as NSError).localizedDescription
        return text.isEmpty ? "We couldn’t complete that request. Please try again." : text
    }
}
