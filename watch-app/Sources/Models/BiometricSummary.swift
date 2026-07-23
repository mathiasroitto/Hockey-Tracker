import Foundation

/// Aggregated HealthKit data for the game.
///
/// Mirrors `BiometricSummary` in `contract/openapi.yaml`.
/// Required: `avgHeartRate`, `maxHeartRate`, `activeEnergyKcal`.
/// `timeInZonesSeconds` is an optional map of zone label -> seconds.
struct BiometricSummary: Codable, Hashable {
    /// Average heart rate, beats per minute.
    let avgHeartRate: Double
    /// Peak heart rate, beats per minute.
    let maxHeartRate: Double
    /// Active energy burned, kilocalories (contract minimum: 0).
    let activeEnergyKcal: Double
    /// Seconds spent in each HR zone (zone label -> seconds). Contract-optional.
    var timeInZonesSeconds: [String: Double]?

    init(
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
