import SwiftUI

@main
struct HockeyTrackerWatchApp: App {
    @StateObject private var store: GameStore
    @StateObject private var workoutManager: WorkoutManager

    init() {
        let store = GameStore()
        _store = StateObject(wrappedValue: store)
        _workoutManager = StateObject(wrappedValue: WorkoutManager(store: store))
        // Make sure WatchConnectivity is up as soon as the app launches.
        _ = WatchSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workoutManager)
        }
    }
}
