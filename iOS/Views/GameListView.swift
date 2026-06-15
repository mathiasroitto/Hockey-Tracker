import SwiftUI

/// Home screen on the phone: a list of synced games plus a live banner when a
/// game is being played on the watch right now.
struct GameListView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var sessionManager: PhoneSessionManager

    var body: some View {
        NavigationStack {
            Group {
                if store.games.isEmpty && sessionManager.liveStatus == nil {
                    EmptyStateView()
                } else {
                    List {
                        if let live = sessionManager.liveStatus {
                            Section {
                                LiveBanner(status: live)
                            }
                        }
                        Section(store.games.isEmpty ? "" : "Games") {
                            ForEach(store.games) { game in
                                NavigationLink {
                                    GameDetailView(game: game)
                                } label: {
                                    GameRow(game: game, stats: store.statistics(for: game))
                                }
                            }
                            .onDelete(perform: deleteGames)
                        }
                    }
                }
            }
            .navigationTitle("Hockey Tracker")
        }
    }

    private func deleteGames(at offsets: IndexSet) {
        offsets.map { store.games[$0] }.forEach(store.delete)
    }
}

private struct GameRow: View {
    let game: Game
    let stats: GameStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.title).font(.headline)
            Text(Format.mediumDate.string(from: game.startDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(stats.shiftCount)", systemImage: "repeat")
                Label(Format.duration(stats.totalDuration), systemImage: "clock")
                Label("\(Format.bpm(stats.averageHeartRate))", systemImage: "heart.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct LiveBanner: View {
    let status: LiveStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Game in progress").font(.headline)
                Text(status.opponent.isEmpty ? "On the watch" : "vs \(status.opponent)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label(status.isOnIce ? "On ice" : "On bench",
                          systemImage: status.isOnIce ? "figure.skating" : "figure.stand")
                    Label("\(status.shiftCount)", systemImage: "repeat")
                    if let hr = status.heartRate {
                        Label("\(Format.bpm(hr))", systemImage: "heart.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Games Yet", systemImage: "hockey.puck.fill")
        } description: {
            Text("Start a game on your Apple Watch. When it ends it will sync here automatically.")
        }
    }
}
