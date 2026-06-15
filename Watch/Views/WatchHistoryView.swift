import SwiftUI

/// A simple list of finished games still stored on the watch. Detailed analysis
/// is done on the iPhone, but this is handy to confirm a game was recorded.
struct WatchHistoryView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        List(store.games) { game in
            VStack(alignment: .leading, spacing: 2) {
                Text(game.title).font(.headline)
                Text(Format.mediumDate.string(from: game.startDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                let stats = store.statistics(for: game)
                Text("\(stats.shiftCount) shifts · \(Format.duration(stats.totalDuration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Past Games")
    }
}
