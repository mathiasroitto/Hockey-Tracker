import Foundation
import Combine

/// Manages a single in-progress game: period tracking, event logging, shift
/// timing, and assembly of the final `GameIngest`.
///
/// This is the source of truth for capture. It is deliberately independent of
/// HealthKit and networking so capture never blocks on either: biometrics are
/// handed in at `endGame`, and syncing happens afterward via `GameSyncManager`.
@MainActor
final class GameSession: ObservableObject {

    // MARK: Game state

    @Published private(set) var isActive = false
    @Published var opponent = ""
    @Published var location = ""
    @Published private(set) var gameDate = Date()
    @Published private(set) var periods = 3
    @Published private(set) var currentPeriod = 1

    @Published private(set) var events: [GameEvent] = []
    @Published private(set) var shifts: [Shift] = []

    /// Start time of the shift currently underway, or `nil` when off the ice.
    @Published private(set) var currentShiftStart: Date?

    var isShiftActive: Bool { currentShiftStart != nil }

    // MARK: Lifecycle

    /// Begin a new game, clearing any prior capture state.
    func startGame(opponent: String, location: String, periods: Int = 3) {
        self.opponent = opponent
        self.location = location
        self.periods = max(1, periods)
        currentPeriod = 1
        gameDate = Date()
        events = []
        shifts = []
        currentShiftStart = nil
        isActive = true
    }

    /// End the game. Closes any open shift, folds in the biometric summary, and
    /// returns the assembled `GameIngest`. Does not touch the network.
    @discardableResult
    func endGame(biometrics: BiometricSummary? = nil) -> GameIngest {
        endShift() // close an in-progress shift if any
        isActive = false

        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return GameIngest(
            date: GameDateFormatting.string(from: gameDate),
            opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines),
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            periods: periods,
            events: events,
            shifts: shifts,
            biometrics: biometrics
        )
    }

    // MARK: Periods

    func nextPeriod() {
        guard isActive else { return }
        currentPeriod = min(currentPeriod + 1, periods)
    }

    func previousPeriod() {
        guard isActive else { return }
        currentPeriod = max(currentPeriod - 1, 1)
    }

    // MARK: Events

    /// Log an event, stamped with the current period and the current UTC instant.
    func logEvent(_ type: EventType, note: String? = nil) {
        guard isActive else { return }
        events.append(
            GameEvent(
                type: type,
                periodNumber: currentPeriod,
                timestamp: Date(),
                note: note
            )
        )
    }

    /// Remove the most recently logged event (undo for a fat-fingered tap).
    func undoLastEvent() {
        guard !events.isEmpty else { return }
        events.removeLast()
    }

    func count(of type: EventType) -> Int {
        events.reduce(0) { $0 + ($1.type == type ? 1 : 0) }
    }

    // MARK: Shifts

    /// Toggle the shift timer: start one if off the ice, stop it if on.
    func toggleShift() {
        if isShiftActive {
            endShift()
        } else {
            startShift()
        }
    }

    func startShift() {
        guard isActive, currentShiftStart == nil else { return }
        currentShiftStart = Date()
    }

    /// Close the open shift, recording its duration. No-op if none is running.
    func endShift() {
        guard let start = currentShiftStart else { return }
        let duration = Date().timeIntervalSince(start)
        shifts.append(
            Shift(
                periodNumber: currentPeriod,
                startTime: start,
                durationSeconds: duration
            )
        )
        currentShiftStart = nil
    }

    /// Seconds elapsed in the current shift, or 0 when off the ice.
    func currentShiftElapsed(asOf now: Date = Date()) -> TimeInterval {
        guard let start = currentShiftStart else { return 0 }
        return now.timeIntervalSince(start)
    }

    var totalIceTimeSeconds: Double {
        shifts.reduce(0) { $0 + $1.durationSeconds }
    }
}
