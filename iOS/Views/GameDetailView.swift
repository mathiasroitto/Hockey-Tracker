import SwiftUI
import Charts

/// Full breakdown of a single synced game: summary tiles, a heart-rate graph,
/// and a per-shift table with recovery and speed.
struct GameDetailView: View {
    let game: Game
    @EnvironmentObject private var store: GameStore

    private var stats: GameStatistics { store.statistics(for: game) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryGrid
                heartRateSection
                shiftsSection
            }
            .padding()
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Summary tiles

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Duration", value: Format.duration(stats.totalDuration), icon: "clock", tint: .green)
            StatTile(title: "Shifts", value: "\(stats.shiftCount)", icon: "repeat", tint: .blue)
            StatTile(title: "Ice Time", value: Format.duration(stats.totalIceTime), icon: "figure.skating", tint: .teal)
            StatTile(title: "Avg Shift", value: Format.shortDuration(stats.averageShiftLength), icon: "timer", tint: .indigo)
            StatTile(title: "Avg HR", value: "\(Format.bpm(stats.averageHeartRate)) bpm", icon: "heart.fill", tint: .red)
            StatTile(title: "Max HR", value: "\(Format.bpm(stats.maxHeartRate)) bpm", icon: "heart.circle.fill", tint: .pink)
            StatTile(title: "Recovery", value: recoveryText, icon: "arrow.down.heart.fill", tint: .purple)
            StatTile(title: "Top Speed", value: "\(Format.speedKmh(stats.maxSpeed)) km/h", icon: "speedometer", tint: .orange)
            StatTile(title: "Distance", value: Format.distance(stats.totalDistance), icon: "map", tint: .mint)
            StatTile(title: "Energy", value: Format.energy(stats.activeEnergyBurned), icon: "flame.fill", tint: .orange)
        }
    }

    private var recoveryText: String {
        guard let drop = stats.averageRecoveryDrop else { return "--" }
        return "-\(Int(drop.rounded())) bpm"
    }

    // MARK: Heart rate chart

    @ViewBuilder
    private var heartRateSection: some View {
        if !game.heartRateSamples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Heart Rate").font(.headline)
                Chart {
                    ForEach(game.heartRateSamples) { sample in
                        LineMark(
                            x: .value("Time", sample.date),
                            y: .value("BPM", sample.bpm)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                    }
                    // Shade time spent on the ice.
                    ForEach(game.shifts) { shift in
                        RectangleMark(
                            xStart: .value("Start", shift.startDate),
                            xEnd: .value("End", shift.endDate ?? game.endDate ?? Date())
                        )
                        .foregroundStyle(.blue.opacity(0.08))
                    }
                }
                .chartYScale(domain: heartRateDomain)
                .frame(height: 200)
                Text("Shaded areas show time on the ice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var heartRateDomain: ClosedRange<Double> {
        let bpms = game.heartRateSamples.map(\.bpm)
        let lower = max(0, (bpms.min() ?? 60) - 10)
        let upper = (bpms.max() ?? 180) + 10
        return lower...upper
    }

    // MARK: Shifts

    @ViewBuilder
    private var shiftsSection: some View {
        if !stats.shifts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shifts").font(.headline)
                ForEach(stats.shifts) { shift in
                    ShiftRow(shift: shift)
                    if shift.id != stats.shifts.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ShiftRow: View {
    let shift: ShiftStatistics

    var body: some View {
        HStack {
            Text("\(shift.number)")
                .font(.headline.monospacedDigit())
                .frame(width: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.shortDuration(shift.duration))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    if let avg = shift.averageHeartRate {
                        Label("\(Int(avg.rounded()))", systemImage: "heart.fill")
                    }
                    if let drop = shift.recoveryDrop {
                        Label("-\(Int(drop.rounded()))", systemImage: "arrow.down.heart")
                    }
                    if let speed = shift.maxSpeed {
                        Label(Format.speedKmh(speed), systemImage: "speedometer")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.time.string(from: shift.startDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
