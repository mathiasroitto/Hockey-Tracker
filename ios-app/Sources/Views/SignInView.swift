import SwiftUI
import AuthenticationServices

/// Signed-out screen with the Sign in with Apple button.
struct SignInView: View {
    @EnvironmentObject private var session: AuthSession
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "hockey.puck.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Hockey Tracker")
                    .font(.largeTitle.bold())
                Text("Your games, stats, and trends — all in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if let error = session.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.signIn) { request in
                session.configure(request)
            } onCompletion: { result in
                session.handleAuthorization(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .frame(maxWidth: 360)

            Text("We only use your Apple ID to secure your data.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
