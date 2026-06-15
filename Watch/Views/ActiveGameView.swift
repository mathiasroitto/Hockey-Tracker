import SwiftUI

/// The screen shown while a game is being recorded. Three swipeable pages:
/// live metrics, the big on-ice / shift button, and game controls.
struct ActiveGameView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        TabView {
            MetricsPage()
            ShiftControlView()
            ControlsPage()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Live metrics page

private struct MetricsPage: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    private var elapsed: TimeInterval {
        guard let start = store.activeGame?.startDate else { return 0 }
        return workoutManager.tick.timeIntervalSince(start)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(Format.duration(elapsed))
                    .font(.system(.title, design: .rounded).monospacedDigit())
                    .foregroundStyle(.green)

                MetricRow(
                    icon: "heart.fill",
                    tint: .red,
                    title: "Heart Rate",
                    value: Format.bpm(workoutManager.currentHeartRate),
                    unit: "bpm"
                )
                MetricRow(
                    icon: "speedometer",
                    tint: .blue,
                    title: "Speed",
                    value: Format.speedKmh(workoutManager.currentSpeed),
                    unit: "km/h"
                )
                MetricRow(
                    icon: "figure.skating",
                    tint: .teal,
                    title: "Distance",
                    value: Format.distance(workoutManager.distance),
                    unit: ""
                )
                MetricRow(
                    icon: "flame.fill",
                    tint: .orange,
                    title: "Energy",
                    value: Format.energy(workoutManager.activeEnergy),
                    unit: ""
                )
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(.title3, design: .rounded).monospacedDigit())
                    if !unit.isEmpty {
                        Text(unit).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}

// MARK: - Controls page

private struct ControlsPage: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Game Controls").font(.headline)
                Button(role: .destructive) {
                    confirmEnd = true
                } label: {
                    Label("End Game", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.red)
            }
            .padding()
        }
        .confirmationDialog(
            "End the game?",
            isPresented: $confirmEnd,
            titleVisibility: .visible
        ) {
            Button("End Game", role: .destructive) { workoutManager.endGame() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("This saves the game and syncs it to your iPhone.")
        }
    }
}
