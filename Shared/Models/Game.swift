import Foundation

/// A single recorded hockey game.
///
/// `Game` only holds *raw* recorded data (shifts and time-stamped samples).
/// All derived numbers — average shift length, heart-rate recovery, top speed,
/// etc. — are computed on demand by `GameStatistics` so that the stored data
/// stays small, lossless and forward-compatible.
///
/// The type is a plain `Codable` value so it can be:
///   * persisted to disk on the watch after every event (survives a dead
///     battery, see `GameStore`), and
///   * encoded and shipped to the iPhone over WatchConnectivity.
struct Game: Codable, Identifiable, Equatable {
    var id: UUID
    /// Optional name of the opposing team, entered on the watch before puck drop.
    var opponent: String
    var startDate: Date
    /// `nil` while the game is still in progress.
    var endDate: Date?

    var shifts: [Shift]
    var heartRateSamples: [HeartRateSample]
    var speedSamples: [SpeedSample]

    /// Total skating distance in meters (from HealthKit's distance series).
    var totalDistance: Double
    /// Active energy burned in kilocalories (from HealthKit).
    var activeEnergyBurned: Double

    init(
        id: UUID = UUID(),
        opponent: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        shifts: [Shift] = [],
        heartRateSamples: [HeartRateSample] = [],
        speedSamples: [SpeedSample] = [],
        totalDistance: Double = 0,
        activeEnergyBurned: Double = 0
    ) {
        self.id = id
        self.opponent = opponent
        self.startDate = startDate
        self.endDate = endDate
        self.shifts = shifts
        self.heartRateSamples = heartRateSamples
        self.speedSamples = speedSamples
        self.totalDistance = totalDistance
        self.activeEnergyBurned = activeEnergyBurned
    }

    var isFinished: Bool { endDate != nil }

    /// The shift currently in progress, if any (a shift with no end date).
    var activeShift: Shift? {
        shifts.last(where: { $0.endDate == nil })
    }

    var isOnIce: Bool { activeShift != nil }

    /// Wall-clock length of the game so far.
    var elapsed: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }

    /// A short human-readable title used in lists.
    var title: String {
        opponent.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Hockey Game"
            : "vs \(opponent)"
    }
}
