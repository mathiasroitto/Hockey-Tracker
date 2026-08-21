import Foundation

/// Mirrors `#/components/schemas/GameEvent`.
/// Required: `id`, `type`, `periodNumber`, `timestamp`.
public struct GameEvent: Codable, Identifiable, Hashable {
    /// UUID string.
    public let id: String
    public let type: EventType
    /// 1-based period number (contract minimum: 1).
    public let periodNumber: Int
    /// ISO-8601 UTC instant the event occurred.
    public let timestamp: Date
    /// Optional free-text note (contract nullable).
    public var note: String?

    public init(
        id: String = UUID().uuidString,
        type: EventType,
        periodNumber: Int,
        timestamp: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.periodNumber = periodNumber
        self.timestamp = timestamp
        self.note = note
    }
}

/// Mirrors `#/components/schemas/Shift`.
/// Required: `id`, `periodNumber`, `startTime`, `durationSeconds`.
public struct Shift: Codable, Identifiable, Hashable {
    /// UUID string.
    public let id: String
    /// 1-based period number (contract minimum: 1).
    public let periodNumber: Int
    /// ISO-8601 UTC instant the shift started.
    public let startTime: Date
    /// Shift length in seconds (contract minimum: 0).
    public let durationSeconds: Double

    public init(
        id: String = UUID().uuidString,
        periodNumber: Int,
        startTime: Date,
        durationSeconds: Double
    ) {
        self.id = id
        self.periodNumber = periodNumber
        self.startTime = startTime
        self.durationSeconds = max(0, durationSeconds)
    }
}

/// Mirrors `#/components/schemas/BiometricSummary`.
/// Aggregated HealthKit data for the game.
/// Required: `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`.
public struct BiometricSummary: Codable, Hashable {
    /// Average heart rate, beats per minute.
    public let avgHeartRate: Double
    /// Peak heart rate, beats per minute.
    public let maxHeartRate: Double
    /// Active energy burned, kilocalories (contract minimum: 0).
    public let activeEnergyKcal: Double
    /// Seconds spent in each HR zone (zone label -> seconds). Contract-optional.
    public var timeInZonesSeconds: [String: Double]?

    public init(
        avgHeartRate: Double,
        maxHeartRate: Double,
        activeEnergyKcal: Double,
        timeInZonesSeconds: [String: Double]? = nil
    ) {
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeEnergyKcal = max(0, activeEnergyKcal)
        self.timeInZonesSeconds = timeInZonesSeconds
    }
}
