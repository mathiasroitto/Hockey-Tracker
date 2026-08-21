import Foundation
import AuthenticationServices
import HockeyContract

/// Observable auth state for the whole app. Owns the Sign in with Apple flow,
/// the current `User`, and coordinates the one-time display-name capture.
@MainActor
final class AuthSession: ObservableObject {

    enum State: Equatable {
        case signedOut
        case authenticating
        case signedIn
    }

    @Published private(set) var state: State
    @Published private(set) var currentUser: User?
    /// Non-nil when the last auth or profile action failed; drives error UI.
    @Published var lastError: String?

    private let api: APIClient
    private let tokenStore: TokenStore

    init(api: APIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
        // If a token was persisted, optimistically start signed-in; the first
        // API call will demote us to signed-out on a 401.
        self.state = tokenStore.identityToken == nil ? .signedOut : .signedIn
    }

    // MARK: - Sign in with Apple

    /// Configures the scopes we request from Apple. `.fullName` is required so
    /// we can capture the display name on the first authorization.
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handles the result delivered by `SignInWithAppleButton`.
    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            // User cancellation is not an error worth surfacing loudly.
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            self.lastError = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.lastError = "Unexpected credential type from Apple."
                return
            }
            guard
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                !token.isEmpty
            else {
                self.lastError = "Apple did not return an identity token."
                return
            }
            tokenStore.save(token: token)
            // Capture the name only if Apple actually provided it (first auth).
            let capturedName = Self.formattedName(from: credential.fullName)
            Task { await self.completeSignIn(capturedName: capturedName) }
        }
    }

    /// After obtaining a token: confirm it via `/me`, then push the captured
    /// name (if any) via `PATCH /me`.
    private func completeSignIn(capturedName: String?) async {
        state = .authenticating
        lastError = nil
        do {
            var user = try await api.me()

            // Only send the name when we genuinely have one. Apple returns the
            // name only on the very first authorization, so `capturedName` is
            // nil on later sign-ins — we must NOT send null and clobber it.
            if let name = capturedName, !name.isEmpty {
                let update = UserUpdate(displayName: .some(name))
                user = try await api.updateMe(update)
            }
            tokenStore.hasCompletedFirstSignIn = true
            currentUser = user
            state = .signedIn
        } catch let error as APIError {
            handleAPIFailure(error)
        } catch {
            lastError = error.localizedDescription
            state = .signedOut
        }
    }

    // MARK: - Session lifecycle

    /// Loads the current user for an already-persisted token (e.g. on launch).
    func refreshCurrentUser() async {
        guard tokenStore.identityToken != nil else {
            state = .signedOut
            return
        }
        do {
            currentUser = try await api.me()
            state = .signedIn
        } catch let error as APIError {
            handleAPIFailure(error)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Sets a new display name from the profile UI (also uses `PATCH /me`).
    func updateDisplayName(_ name: String?) async {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        // `.some(nil)` clears; `.some("x")` sets. We never send `.none` here
        // because the user explicitly acted.
        let value: String? = (trimmed?.isEmpty ?? true) ? nil : trimmed
        do {
            currentUser = try await api.updateMe(UserUpdate(displayName: .some(value)))
        } catch let error as APIError {
            handleAPIFailure(error)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        tokenStore.clear()
        currentUser = nil
        lastError = nil
        state = .signedOut
    }

    /// Centralizes 401 handling: expired/invalid token → back to signed out.
    private func handleAPIFailure(_ error: APIError) {
        switch error {
        case .unauthorized:
            tokenStore.clear()
            currentUser = nil
            state = .signedOut
            lastError = "Your session expired. Please sign in again."
        default:
            lastError = error.errorDescription
            if state == .authenticating { state = .signedOut }
        }
    }

    // MARK: - Helpers

    /// Formats `ASAuthorizationAppleIDCredential.fullName` into a display name.
    static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }
}
