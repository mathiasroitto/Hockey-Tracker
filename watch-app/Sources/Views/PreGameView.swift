import SwiftUI

/// Pre-game setup: opponent, optional location, and period count, then start.
struct PreGameView: View {
    @EnvironmentObject private var game: GameSession
    @EnvironmentObject private var health: HealthKitManager

    @State private var opponent = ""
    @State private var location = ""
    @State private var periods = 3

    var onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TextField("Opponent", text: $opponent)
                    .textFieldStyle(.plain)
                TextField("Location (optional)", text: $location)
                    .textFieldStyle(.plain)

                Stepper(value: $periods, in: 1...5) {
                    Text("Periods: \(periods)")
                }

                Button {
                    game.startGame(
                        opponent: opponent.isEmpty ? "Opponent" : opponent,
                        location: location,
                        periods: periods
                    )
                    health.startWorkout()
                    onStart()
                } label: {
                    Label("Start Game", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.inline)
        .task { await health.requestAuthorization() }
    }
}
