import SwiftUI
import Charts
import HockeyContract

/// Per-game detail: box score (from `GameStats`), a shift chart (from the
/// game's shifts), and the biometric summary. All numbers are server-computed.
struct GameDetailView: View {
    let gameId: String

    @Environment(\.apiClient) private var api
    @StateObject private var content = Loadable<(game: Game, stats: GameStats)>()

    var body: some View {
        AsyncContentView(loadable: content) { value in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(value.game)
                    BoxScoreSection(stats: value.stats)
                    if !value.game.shifts.isEmpty {
                        ShiftChartSection(shifts: value.game.shifts)
                    }
                    if let bio = value.stats.biometrics ?? value.game.biometrics {
                        BiometricSection(bio: bio)
                    }
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading) // readable on iPad
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let client = api
            let id = gameId
            await content.load {
                async let game = client.game(id: id)
                async let stats = client.gameStats(id: id)
                return try await (game: game, stats: stats)
            }
        }
    }

    private func header(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("vs \(game.opponent)")
                .font(.title.bold())
            HStack(spacing: 14) {
                Label(Format.gameDate(game.date), systemImage: "calendar")
                if let location = game.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Box score

private struct BoxScoreSection: View {
    let stats: GameStats

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Box score").font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "Goals", value: "\(stats.goals)")
                StatTile(title: "Assists", value: "\(stats.assists)")
                StatTile(title: "Points", value: "\(stats.points)")
                StatTile(title: "Shots", value: "\(stats.shots)")
                StatTile(title: "Shooting", value: Format.percent(stats.shootingPct))
                StatTile(title: "Faceoffs", value: Format.percent(stats.faceoffPct))
                StatTile(title: "Hits", value: "\(stats.hits)")
                StatTile(title: "Blocks", value: "\(stats.blocks)")
                StatTile(title: "Penalties", value: "\(stats.penalties)")
                StatTile(title: "Ice time", value: Format.duration(stats.totalIceTimeSeconds))
                StatTile(title: "Shifts", value: "\(stats.shiftCount)")
                if let avg = stats.avgShiftSeconds {
                    StatTile(title: "Avg shift", value: Format.duration(avg))
                }
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shift chart

private struct ShiftChartSection: View {
    let shifts: [Shift]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shifts").font(.headline)
            Chart(Array(shifts.enumerated()), id: \.element.id) { item in
                BarMark(
                    x: .value("Shift", item.offset + 1),
                    y: .value("Seconds", item.element.durationSeconds)
                )
                .foregroundStyle(by: .value("Period", "P\(item.element.periodNumber)"))
            }
            .chartXAxisLabel("Shift #")
            .chartYAxisLabel("Seconds")
            .frame(height: 220)
        }
    }
}

// MARK: - Biometrics

private struct BiometricSection: View {
    let bio: BiometricSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biometrics").font(.headline)
            HStack(spacing: 12) {
                StatTile(title: "Avg HR", value: "\(Format.rounded(bio.avgHeartRate)) bpm")
                StatTile(title: "Max HR", value: "\(Format.rounded(bio.maxHeartRate)) bpm")
                StatTile(title: "Energy", value: "\(Format.rounded(bio.activeEnergyKcal)) kcal")
            }
            if let zones = bio.timeInZonesSeconds, !zones.isEmpty {
                Text("Time in heart-rate zones").font(.subheadline.bold())
                Chart(zones.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                    BarMark(
                        x: .value("Seconds", entry.value),
                        y: .value("Zone", entry.key)
                    )
                }
                .frame(height: CGFloat(zones.count) * 44 + 20)
            }
        }
    }
}
