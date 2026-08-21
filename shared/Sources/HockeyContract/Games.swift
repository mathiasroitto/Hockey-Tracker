import Foundation

/// Mirrors `#/components/schemas/GameIngest` — the payload the Watch uploads
/// after a game.
///
/// `date` is a **calendar day** (contract `format: date`). It is modeled as a
/// `Date` for a clean domain type, but coded explicitly as `yyyy-MM-dd` (UTC) so
/// it never serializes as a full timestamp — independent of the encoder's
/// date-time strategy, which governs the nested event/shift instants.
public struct GameIngest: Codable, Hashable {
    public let date: Date
    public let opponent: String
    /// Rink / venue (contract nullable).
    public var location: String?
    /// Number of periods (contract default 3, minimum 1).
    public var periods: Int
    public var events: [GameEvent]
    public var shifts: [Shift]
    /// HealthKit roll-up (contract nullable).
    public var biometrics: BiometricSummary?

    public init(
        date: Date,
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

    enum CodingKeys: String, CodingKey {
        case date, opponent, location, periods, events, shifts, biometrics
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The decoder's lenient date strategy handles the yyyy-MM-dd form.
        date = try c.decode(Date.self, forKey: .date)
        opponent = try c.decode(String.self, forKey: .opponent)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        periods = try c.decodeIfPresent(Int.self, forKey: .periods) ?? 3
        events = try c.decode([GameEvent].self, forKey: .events)
        shifts = try c.decode([Shift].self, forKey: .shifts)
        biometrics = try c.decodeIfPresent(BiometricSummary.self, forKey: .biometrics)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // Calendar day as yyyy-MM-dd, NOT an instant.
        try c.encode(ContractDate.calendarString(from: date), forKey: .date)
        try c.encode(opponent, forKey: .opponent)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encode(periods, forKey: .periods)
        // Nested instants (event timestamps, shift start times) use the
        // encoder's date-time strategy.
        try c.encode(events, forKey: .events)
        try c.encode(shifts, forKey: .shifts)
        try c.encodeIfPresent(biometrics, forKey: .biometrics)
    }
}

/// Mirrors `#/components/schemas/Game` (`GameIngest` + `id` + `createdAt`).
///
/// A server response; clients decode it. `createdAt` is a date-time instant and
/// `date` is a calendar day — both `Date`, both handled by the shared coder.
public struct Game: Codable, Identifiable, Hashable {
    public let id: String
    public let createdAt: Date
    public let date: Date
    public let opponent: String
    public let location: String?
    public let periods: Int
    public let events: [GameEvent]
    public let shifts: [Shift]
    public let biometrics: BiometricSummary?

    public init(
        id: String,
        createdAt: Date,
        date: Date,
        opponent: String,
        location: String? = nil,
        periods: Int = 3,
        events: [GameEvent],
        shifts: [Shift],
        biometrics: BiometricSummary? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.date = date
        self.opponent = opponent
        self.location = location
        self.periods = periods
        self.events = events
        self.shifts = shifts
        self.biometrics = biometrics
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, date, opponent, location, periods, events, shifts, biometrics
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        date = try c.decode(Date.self, forKey: .date)
        opponent = try c.decode(String.self, forKey: .opponent)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        periods = try c.decodeIfPresent(Int.self, forKey: .periods) ?? 3
        events = try c.decode([GameEvent].self, forKey: .events)
        shifts = try c.decode([Shift].self, forKey: .shifts)
        biometrics = try c.decodeIfPresent(BiometricSummary.self, forKey: .biometrics)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt) // instant, via encoder strategy
        try c.encode(ContractDate.calendarString(from: date), forKey: .date)
        try c.encode(opponent, forKey: .opponent)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encode(periods, forKey: .periods)
        try c.encode(events, forKey: .events)
        try c.encode(shifts, forKey: .shifts)
        try c.encodeIfPresent(biometrics, forKey: .biometrics)
    }
}
