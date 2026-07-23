import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Phone side of the Sign in with Apple token hand-off.
///
/// The iOS app owns authentication, so it is the *source of truth* for the
/// current identity token. This coordinator mirrors that state onto the paired
/// Apple Watch using `WCSession.updateApplicationContext(_:)` — the transport
/// designed to always hold a single "latest value" that is overwritten on each
/// update and delivered when the watch next becomes reachable or launches.
///
/// Shared contract with the watch side (do not deviate):
/// - `"signedIn"`      : Bool   — whether the phone has an authenticated user.
/// - `"identityToken"` : String — the current identity token when signed in;
///                                the empty string `""` when signed out.
///
/// Resilience is deliberate: every guard fails soft and every error is only
/// logged. Nothing here may crash the app or block the sign-in flow.
final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    /// App-wide singleton; started once from `HockeyTrackerApp`.
    static let shared = WatchConnectivityManager()

    /// Application-context dictionary keys. These are the shared contract with
    /// the watch app — keep them byte-for-byte identical on both sides.
    enum ContextKey {
        static let signedIn = "signedIn"
        static let identityToken = "identityToken"
    }

    /// Immutable, comparable view of what we last computed. Deduping on this
    /// (rather than on `AuthSession.State`) means a token *refresh* — which
    /// keeps `signedIn == true` but changes the token — still triggers a push.
    private struct AuthSnapshot: Equatable {
        let signedIn: Bool
        let token: String

        static let signedOut = AuthSnapshot(signedIn: false, token: "")
    }

    private let lock = NSLock()
    private var latest: AuthSnapshot = .signedOut
    private var cancellable: AnyCancellable?
    private weak var tokenStore: TokenProviding?

    private override init() { super.init() }

    // MARK: - Startup

    /// Activates the session and starts mirroring auth state to the watch.
    ///
    /// Call once at app launch. `authSession.$state` transitions drive the
    /// pushes; the token itself is read from `tokenStore` at push time (the
    /// token is always persisted before the state flips to `.signedIn`).
    @MainActor
    func start(authSession: AuthSession, tokenStore: TokenProviding) {
        self.tokenStore = tokenStore

        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif

        // Observe auth-state transitions and translate them into the contract
        // payload. `.authenticating` is transient and intentionally ignored so
        // a re-authentication (refresh) never briefly reports "signed out".
        cancellable = authSession.$state
            .compactMap { [weak self] state -> AuthSnapshot? in
                switch state {
                case .signedIn:
                    return AuthSnapshot(signedIn: true, token: self?.tokenStore?.identityToken ?? "")
                case .signedOut:
                    return .signedOut
                case .authenticating:
                    return nil
                }
            }
            .removeDuplicates()
            .sink { [weak self] snapshot in
                self?.apply(snapshot)
            }
    }

    // MARK: - Pushing state

    private func apply(_ snapshot: AuthSnapshot) {
        lock.lock()
        latest = snapshot
        lock.unlock()
        push(snapshot)
    }

    private func currentSnapshot() -> AuthSnapshot {
        lock.lock(); defer { lock.unlock() }
        return latest
    }

    /// Overwrites the watch's application context with the latest auth state.
    /// Guards are best-effort; failures are logged and swallowed.
    private func push(_ snapshot: AuthSnapshot) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        // If we're not activated yet, skip — `activationDidCompleteWith` will
        // flush the current snapshot once activation succeeds.
        guard session.activationState == .activated else { return }

        // No point (and not always valid) pushing when there's no watch app.
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let context: [String: Any] = [
            ContextKey.signedIn: snapshot.signedIn,
            ContextKey.identityToken: snapshot.token
        ]

        do {
            try session.updateApplicationContext(context)
        } catch {
            NSLog("WatchConnectivity: updateApplicationContext failed: %@", String(describing: error))
        }
        #endif
    }
}

// MARK: - WCSessionDelegate

#if canImport(WatchConnectivity)
extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            NSLog("WatchConnectivity: activation error: %@", String(describing: error))
        }
        guard activationState == .activated else { return }
        // A freshly launched phone syncs the watch with its current state.
        push(currentSnapshot())
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // The session pauses while switching watches; nothing to do here.
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so the hand-off keeps working after the user switches to a
        // different paired watch.
        session.activate()
    }
    #endif
}
#endif
