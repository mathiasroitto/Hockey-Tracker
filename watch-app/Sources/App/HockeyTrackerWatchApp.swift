import SwiftUI

/// App entry point. Wires the capture, health, and sync objects and injects them
/// into the view tree.
///
/// Configuration seams (see report / CLAUDE.md):
/// - `APIClient.baseURL` defaults to `http://localhost:8000` (contract dev server).
/// - `WatchConnectivityTokenProvider` is the auth seam: the paired iPhone runs
///   Sign in with Apple and pushes the identity token via WatchConnectivity
///   application context; this provider caches it and feeds `APIClient`.
@main
struct HockeyTrackerWatchApp: App {
    @StateObject private var game = GameSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var sync: GameSyncManager

    /// Held so its `WCSession` stays activated for the app's lifetime.
    private let tokenProvider: WatchConnectivityTokenProvider

    init() {
        // The token is delivered from the phone over WatchConnectivity; this
        // provider activates WCSession and caches the latest identity token.
        // Base URL is overridable for a real server.
        let tokenProvider = WatchConnectivityTokenProvider()
        tokenProvider.activate()
        self.tokenProvider = tokenProvider

        let client = APIClient(
            baseURL: URL(string: "http://localhost:8000")!,
            tokenProvider: tokenProvider
        )
        _sync = StateObject(wrappedValue: GameSyncManager(client: client))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(health)
                .environmentObject(sync)
        }
    }
}
