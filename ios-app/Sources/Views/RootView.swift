import SwiftUI

/// Top-level view: switches between the signed-out and signed-in experiences.
struct RootView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        Group {
            switch session.state {
            case .signedOut:
                SignInView()
            case .authenticating:
                ProgressView("Signing in…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedIn:
                HomeView()
            }
        }
        .task {
            // If launched with a persisted token but no user yet, fetch it.
            if session.state == .signedIn && session.currentUser == nil {
                await session.refreshCurrentUser()
            }
        }
    }
}
