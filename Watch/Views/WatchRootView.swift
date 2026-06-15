import SwiftUI

/// Top-level router for the watch app. Decides which screen to show based on the
/// recording phase and whether an unfinished game was recovered from disk.
struct WatchRootView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        switch workoutManager.phase {
        case .active:
            ActiveGameView()
        case .ended:
            GameSummaryView()
        case .failed(let message):
            FailureView(message: message)
        case .idle, .requestingAuthorization:
            // An unfinished game on disk means the last session ended abnormally
            // (battery died / app killed). Offer to resume or save it.
            if let recovered = store.activeGame, !recovered.isFinished {
                RecoveredGameView(game: recovered)
            } else {
                StartGameView()
            }
        }
    }
}

private struct FailureView: View {
    let message: String
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                Text("Tracking error").font(.headline)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("OK") { workoutManager.reset() }
            }
            .padding()
        }
    }
}
