import SwiftUI

/// Shown on launch when an unfinished game is found on disk — i.e. the watch
/// died or the app was killed mid-game. The recording is intact; let the player
/// resume it, save it as-is, or discard it.
struct RecoveredGameView: View {
    let game: Game

    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Unfinished Game").font(.headline)
                Text("Started \(Format.mediumDate.string(from: game.startDate))")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("\(game.shifts.count) shifts recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    workoutManager.resumeRecoveredGame()
                } label: {
                    Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    workoutManager.endGame()
                } label: {
                    Label("Save & Finish", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    store.discardActiveGame()
                } label: {
                    Label("Discard", systemImage: "trash").frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
        }
    }
}
