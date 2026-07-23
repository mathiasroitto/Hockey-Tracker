import SwiftUI

/// App entry point. Wires the capture, health, and sync objects and injects them
/// into the view tree.
///
/// Configuration seams (see report / CLAUDE.md):
/// - `APIClient.baseURL` defaults to `http://localhost:8000` (contract dev server).
/// - `PlaceholderTokenProvider` is the MVP auth seam; in production a
///   WatchConnectivity receiver sets the token delivered by the paired iPhone.
@main
struct HockeyTrackerWatchApp: App {
    @StateObject private var game = GameSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var sync: GameSyncManager

    init() {
        // TODO: replace the placeholder token with one delivered from the phone
        // over WatchConnectivity. Base URL is overridable for a real server.
        let tokenProvider = PlaceholderTokenProvider(token: nil)
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
