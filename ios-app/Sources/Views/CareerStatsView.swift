import SwiftUI
import Charts
import HockeyContract

/// Aggregate view: career totals and a simple points/shooting summary. All
/// figures come straight from `GET /stats/career` — no client-side math.
struct CareerStatsView: View {
    @Environment(\.apiClient) private var api
    @StateObject private var stats = Loadable<CareerStats>()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        AsyncContentView(
            loadable: stats,
            isEmpty: { $0.gamesPlayed == 0 },
            emptyMessage: "Play a game to start building your career stats."
        ) { career in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        StatTile(title: "Games", value: "\(career.gamesPlayed)")
                        StatTile(title: "Goals", value: "\(career.totalGoals)")
                        StatTile(title: "Assists", value: "\(career.totalAssists)")
                        StatTile(title: "Points", value: "\(career.totalPoints)")
                        StatTile(title: "Points/Game", value: Format.oneDecimal(career.pointsPerGame))
                        if let shots = career.totalShots {
                            StatTile(title: "Shots", value: "\(shots)")
                        }
                        if let pct = career.shootingPct {
                            StatTile(title: "Shooting", value: Format.percent(pct))
                        }
                        if let ice = career.avgIceTimeSeconds {
                            StatTile(title: "Avg Ice", value: Format.duration(ice))
                        }
                    }

                    PointsBreakdownChart(
                        goals: career.totalGoals,
                        assists: career.totalAssists
                    )
                }
                .padding()
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Career")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let client = api
            await stats.load { try await client.careerStats() }
        }
    }
}

/// Simple points composition: goals vs assists.
private struct PointsBreakdownChart: View {
    let goals: Int
    let assists: Int

    private var data: [(label: String, value: Int)] {
        [("Goals", goals), ("Assists", assists)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Points breakdown").font(.headline)
            if goals == 0 && assists == 0 {
                Text("No points recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data, id: \.label) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("Type", item.label)
                    )
                    .foregroundStyle(by: .value("Type", item.label))
                    .annotation(position: .trailing) {
                        Text("\(item.value)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 140)
            }
        }
    }
}
