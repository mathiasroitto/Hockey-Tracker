import Foundation

/// Supplies the bearer token attached to every authenticated request.
///
/// Auth seam / coordination note
/// ------------------------------
/// The contract requires a Sign in with Apple **identity token** (JWT) in the
/// `Authorization: Bearer <token>` header (see `appleIdentityToken` in
/// `contract/openapi.yaml`). Per `watch-app/CLAUDE.md`, the first Sign in with
/// Apple authorization is normally driven by the **paired iPhone**, which also
/// captures the display name and calls `PATCH /me`. The Watch then just
/// *consumes* the resulting token.
///
/// This protocol is the seam for that. The MVP ships a placeholder; the intended
/// production implementation receives the token from the phone over
/// `WatchConnectivity` (`WCSession` / `transferUserInfo` / application context)
/// and caches it. Do NOT implement phone-side sign-in here.
protocol TokenProvider: Sendable {
    /// The current bearer token, or `nil` if none is available yet.
    /// Must never block on the network / user interaction in a way that would
    /// stall capture — return what is cached.
    func currentToken() async -> String?
}

/// MVP placeholder. Holds a token injected out-of-band (e.g. hard-coded during
/// development, or later set by a WatchConnectivity receiver). Thread-safe.
final class PlaceholderTokenProvider: TokenProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func setToken(_ token: String?) {
        lock.lock(); defer { lock.unlock() }
        self.token = token
    }

    func currentToken() async -> String? {
        lock.lock(); defer { lock.unlock() }
        return token
    }
}
