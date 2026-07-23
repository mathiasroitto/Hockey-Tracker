import Foundation

/// Persists the Sign in with Apple identity token and exposes it to `APIClient`.
///
/// This is deliberately a plain, non-actor-isolated class so the networking
/// layer can read the token from any thread. It conforms to `TokenProviding`.
///
/// STORAGE TRADEOFF (MVP): the token is cached in memory and mirrored to
/// `UserDefaults` for a "stay signed in" experience across launches. For
/// production this should move to the Keychain — UserDefaults is not encrypted
/// and is included in device backups. Note also that Apple identity tokens are
/// short-lived JWTs, so a persisted token often expires between launches; the
/// app handles that by treating a 401 as "sign in again".
final class TokenStore: TokenProviding, @unchecked Sendable {

    private let defaults: UserDefaults
    private let tokenKey = "hockeytracker.identityToken"
    private let firstSignInKey = "hockeytracker.didCompleteFirstSignIn"
    private let lock = NSLock()
    private var cachedToken: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cachedToken = defaults.string(forKey: tokenKey)
    }

    // MARK: TokenProviding

    var identityToken: String? {
        lock.lock(); defer { lock.unlock() }
        return cachedToken
    }

    // MARK: Mutation

    func save(token: String?) {
        lock.lock()
        cachedToken = token
        lock.unlock()
        if let token {
            defaults.set(token, forKey: tokenKey)
        } else {
            defaults.removeObject(forKey: tokenKey)
        }
    }

    /// Tracks whether we've already completed a first authorization on this
    /// device. Used to decide whether to expect `fullName` from Apple.
    var hasCompletedFirstSignIn: Bool {
        get { defaults.bool(forKey: firstSignInKey) }
        set { defaults.set(newValue, forKey: firstSignInKey) }
    }

    func clear() {
        save(token: nil)
    }
}
