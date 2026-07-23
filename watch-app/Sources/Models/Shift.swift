import Foundation

/// A single shift on the ice.
///
/// Mirrors `Shift` in `contract/openapi.yaml`.
/// Required: `id`, `periodNumber`, `startTime`, `durationSeconds`.
struct Shift: Codable, Identifiable, Hashable {
    /// UUID string.
    let id: String
    /// 1-based period number (contract minimum: 1).
    let periodNumber: Int
    /// ISO-8601 UTC instant the shift started.
    let startTime: Date
    /// Shift length in seconds (contract minimum: 0).
    let durationSeconds: Double

    init(
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
