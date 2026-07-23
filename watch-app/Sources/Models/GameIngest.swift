import Foundation

/// The payload the Watch uploads after a game.
///
/// Mirrors `GameIngest` in `contract/openapi.yaml`.
/// Required: `date`, `opponent`, `events`, `shifts`.
/// Optional/nullable: `location`, `periods` (default 3), `biometrics`.
struct GameIngest: Codable, Hashable {
    /// Calendar date `yyyy-MM-dd` (contract `format: date`), UTC.
    /// Kept as a `String` so it never serializes as a full timestamp.
    let date: String
    let opponent: String
    /// Rink / venue (contract nullable).
    var location: String?
    /// Number of periods (contract default 3, minimum 1).
    var periods: Int
    var events: [GameEvent]
    var shifts: [Shift]
    /// HealthKit roll-up (contract nullable).
    var biometrics: BiometricSummary?

    init(
        date: String,
        opponent: String,
        location: String? = nil,
        periods: Int = 3,
        events: [GameEvent],
        shifts: [Shift],
        biometrics: BiometricSummary? = nil
    ) {
        self.date = date
        self.opponent = opponent
        self.location = location
        self.periods = periods
        self.events = events
        self.shifts = shifts
        self.biometrics = biometrics
    }
}
