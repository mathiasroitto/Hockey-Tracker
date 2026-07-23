import SwiftUI

@main
struct HockeyTrackerApp: App {

    @StateObject private var session: AuthSession
    private let api: APIClient

    init() {
        // Base URL: local dev server by default. Point this at your deployed
        // server for a real build. The bundle id (com.hockeytracker.ios) is the
        // Sign in with Apple audience and must equal the server APPLE_CLIENT_ID.
        let tokenStore = TokenStore()
        let api = APIClient(baseURL: AppConfig.baseURL, tokenProvider: tokenStore)
        self.api = api
        _session = StateObject(wrappedValue: AuthSession(api: api, tokenStore: tokenStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.apiClient, api)
        }
    }
}

/// App-wide configuration knobs.
enum AppConfig {
    /// Dev default. Override with the `HT_BASE_URL` environment variable when
    /// running a scheme against a different server.
    static var baseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["HT_BASE_URL"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:8000")!
    }
}

// MARK: - APIClient environment injection

private struct APIClientKey: EnvironmentKey {
    static let defaultValue = APIClient()
}

extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
