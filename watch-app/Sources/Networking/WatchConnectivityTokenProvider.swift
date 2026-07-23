import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// `TokenProvider` backed by WatchConnectivity.
///
/// Auth hand-off (watch side)
/// --------------------------
/// The **paired iPhone** owns Sign in with Apple. Whenever its auth state
/// changes, it publishes the single latest state via
/// `WCSession.updateApplicationContext(_:)`. The application context always
/// holds the most recent value and is delivered when the watch next becomes
/// reachable or launches, which makes it the right transport for "the current
/// token" (as opposed to a queue of messages).
///
/// Shared application-context contract (MUST match the iOS side exactly):
/// - `"signedIn"`      `Bool`   — whether the phone has an authenticated user.
/// - `"identityToken"` `String` — the current Sign in with Apple identity token
///                                when `signedIn` is true; empty `""` otherwise.
///
/// This type applies the latest context both at activation (by reading
/// `session.receivedApplicationContext`) and live (via
/// `session(_:didReceiveApplicationContext:)`). When `signedIn` is true it
/// stores the token; when false (or the token is empty) it clears it. With no
/// token, `currentToken()` returns `nil`, so `APIClient` throws
/// `.missingToken` and the game stays buffered — capture is never blocked.
final class WatchConnectivityTokenProvider: NSObject, TokenProvider, @unchecked Sendable {

    /// Shared application-context keys. Must stay identical to the iOS app.
    enum ContextKey {
        static let signedIn = "signedIn"
        static let identityToken = "identityToken"
    }

    private let lock = NSLock()
    private var token: String?

    override init() {
        super.init()
    }

    /// Activate `WCSession` and start receiving auth state from the phone.
    /// Safe to call at launch; a no-op on platforms/devices without support.
    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    /// The latest bearer token, or `nil` when signed out / not yet received.
    /// Never blocks — returns the cached value.
    func currentToken() async -> String? {
        lock.lock(); defer { lock.unlock() }
        return token
    }

    // MARK: - Context application

    /// Apply a received application context, storing or clearing the token per
    /// the shared semantics. Empty/absent token or `signedIn == false` clears it.
    private func apply(context: [String: Any]) {
        let signedIn = context[ContextKey.signedIn] as? Bool ?? false
        let received = context[ContextKey.identityToken] as? String ?? ""

        lock.lock(); defer { lock.unlock() }
        if signedIn && !received.isEmpty {
            token = received
        } else {
            token = nil
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityTokenProvider: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Adopt whatever the phone last published before we activated.
        apply(context: session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Live updates while the app is running.
        apply(context: applicationContext)
    }
}
#endif
