import SwiftUI

@main
struct HockeyTrackerApp: App {
    @StateObject private var store: GameStore
    @StateObject private var sessionManager: PhoneSessionManager

    init() {
        let store = GameStore()
        _store = StateObject(wrappedValue: store)
        _sessionManager = StateObject(wrappedValue: PhoneSessionManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            GameListView()
                .environmentObject(store)
                .environmentObject(sessionManager)
        }
    }
}
