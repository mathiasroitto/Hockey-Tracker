import SwiftUI

/// The big on-ice / off-ice button — the player's main interaction during a
/// game. Tap when you jump on the ice, tap again when you come off.
struct ShiftControlView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var workoutManager: WorkoutManager

    private var isOnIce: Bool { workoutManager.isOnIce }

    private var currentShiftDuration: TimeInterval {
        guard let shift = store.activeGame?.activeShift else { return 0 }
        return workoutManager.tick.timeIntervalSince(shift.startDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(isOnIce ? "ON ICE" : "ON BENCH")
                    .font(.caption).bold()
                    .foregroundStyle(isOnIce ? .green : .secondary)

                if isOnIce {
                    Text(Format.duration(currentShiftDuration))
                        .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                        .foregroundStyle(.green)
                } else {
                    Text("Shift \(workoutManager.shiftCount)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button {
                    workoutManager.toggleShift()
                } label: {
                    Label(
                        isOnIce ? "End Shift" : "Start Shift",
                        systemImage: isOnIce ? "figure.stand" : "figure.skating"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(isOnIce ? .red : .green)

                Text("\(workoutManager.shiftCount) shifts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
