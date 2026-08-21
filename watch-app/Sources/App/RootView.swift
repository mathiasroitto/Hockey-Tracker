import SwiftUI
import HockeyContract

/// Drives the capture flow: pre-game -> live capture -> end-of-game summary.
struct RootView: View {
    @EnvironmentObject private var game: GameSession
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var sync: GameSyncManager

    private enum Phase: Equatable {
        case preGame
        case capturing
        case ended
    }

    @State private var phase: Phase = .preGame
    @State private var finishedGame: GameIngest?

    var body: some View {
        NavigationStack {
            switch phase {
            case .preGame:
                PreGameView(onStart: { phase = .capturing })
            case .capturing:
                CaptureView(onEndGame: endGame)
            case .ended:
                if let finishedGame {
                    EndGameView(ingest: finishedGame, onDone: reset)
                } else {
                    // Should not happen; recover gracefully.
                    PreGameView(onStart: { phase = .capturing })
                }
            }
        }
    }

    private func endGame() {
        Task {
            // Stop the workout first so the summary reflects the full game,
            // then assemble + buffer the ingest. Sync is fire-and-forget.
            await health.stopWorkout()
            let biometrics = health.makeSummary()
            let ingest = game.endGame(biometrics: biometrics)
            finishedGame = ingest
            sync.enqueue(ingest)
            phase = .ended
        }
    }

    private func reset() {
        finishedGame = nil
        phase = .preGame
    }
}
