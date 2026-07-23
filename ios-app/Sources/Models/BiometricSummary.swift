import Foundation

/// Mirrors `#/components/schemas/BiometricSummary`.
/// Aggregated HealthKit data for the game.
struct BiometricSummary: Codable, Equatable {
    let avgHeartRate: Double        // beats per minute
    let maxHeartRate: Double        // beats per minute
    let activeEnergyKcal: Double    // minimum 0
    /// Seconds spent in each HR zone (zone label → seconds). Optional.
    let timeInZonesSeconds: [String: Double]?
}
