import SwiftUI
import HockeyContract
#if canImport(WatchKit)
import WatchKit
#endif

/// The live capture screen: period control, event grid, shift toggle, and a
/// compact live counter. Designed for cold hands — large targets, high contrast,
/// minimal taps.
struct CaptureView: View {
    @EnvironmentObject private var game: GameSession
    @EnvironmentObject private var health: HealthKitManager

    /// Drives the live shift-timer readout.
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var onEndGame: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                periodBar
                counterRow
                shiftButton
                eventGrid
                bottomControls
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(game.opponent.isEmpty ? "Game" : game.opponent)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticker) { now = $0 }
    }

    private var periodBar: some View {
        HStack(spacing: 6) {
            Button {
                game.previousPeriod()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)

            VStack(spacing: 0) {
                Text("PERIOD").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Text("\(game.currentPeriod)/\(game.periods)").font(.title3.bold()).monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            Button {
                game.nextPeriod()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
        }
    }

    private var counterRow: some View {
        HStack(spacing: 8) {
            ForEach(EventButtonLayout.counters) { type in
                VStack(spacing: 0) {
                    Text("\(game.count(of: type))").font(.headline.bold()).monospacedDigit()
                    Text(type.shortLabel).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            if health.latestHeartRate > 0 {
                VStack(spacing: 0) {
                    Text("\(Int(health.latestHeartRate))").font(.headline.bold()).monospacedDigit()
                    Text("BPM").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 2)
    }

    private var shiftButton: some View {
        Button {
            game.toggleShift()
        } label: {
            HStack {
                Image(systemName: game.isShiftActive ? "stop.fill" : "play.fill")
                Text(game.isShiftActive
                     ? "Shift \(formatDuration(game.currentShiftElapsed(asOf: now)))"
                     : "Start Shift")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(game.isShiftActive ? .red : .green)
    }

    private var eventGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(EventButtonLayout.ordered) { type in
                Button {
                    game.logEvent(type)
                    WatchHaptics.tap()
                } label: {
                    Text(type.shortLabel)
                        .font(.system(size: 15, weight: .bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(type.tint)
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 6) {
            Button {
                game.undoLastEvent()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                onEndGame()
            } label: {
                Label("End", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }
}

/// Thin haptics wrapper so views don't import WatchKit directly.
enum WatchHaptics {
    static func tap() {
#if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
#endif
    }
}
