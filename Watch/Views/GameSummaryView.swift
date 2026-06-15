import SwiftUI

/// Shown right after a game ends: a quick recap before returning to the start
/// screen. Full stats live on the iPhone after syncing.
struct GameSummaryView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    private var game: Game? { store.games.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Game Saved").font(.headline)
                Text("Synced to your iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let game {
                    let stats = store.statistics(for: game)
                    SummaryStat(label: "Duration", value: Format.duration(stats.totalDuration))
                    SummaryStat(label: "Shifts", value: "\(stats.shiftCount)")
                    SummaryStat(label: "Avg shift", value: Format.shortDuration(stats.averageShiftLength))
                    SummaryStat(label: "Avg HR", value: "\(Format.bpm(stats.averageHeartRate)) bpm")
                    SummaryStat(label: "Max HR", value: "\(Format.bpm(stats.maxHeartRate)) bpm")
                    SummaryStat(label: "Top speed", value: "\(Format.speedKmh(stats.maxSpeed)) km/h")
                }

                Button("Done") { workoutManager.reset() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct SummaryStat: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .rounded)).bold()
        }
    }
}
