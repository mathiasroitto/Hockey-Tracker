import Foundation

/// Mirrors `#/components/schemas/GameIngest`.
/// The payload the Watch uploads after a game. iOS only needs this for the
/// optional relay of a captured game to the server.
struct GameIngest: Codable, Equatable {
    let date: Date              // format: date (calendar day)
    let opponent: String
    let location: String?       // nullable
    let periods: Int            // default 3, minimum 1
    let events: [GameEvent]
    let shifts: [Shift]
    let biometrics: BiometricSummary?

    init(
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        opponent = try c.decode(String.self, forKey: .opponent)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        periods = try c.decodeIfPresent(Int.self, forKey: .periods) ?? 3
        events = try c.decode([GameEvent].self, forKey: .events)
        shifts = try c.decode([Shift].self, forKey: .shifts)
        biometrics = try c.decodeIfPresent(BiometricSummary.self, forKey: .biometrics)
    }

    enum CodingKeys: String, CodingKey {
        case date, opponent, location, periods, events, shifts, biometrics
    }
}

/// Mirrors `#/components/schemas/Game` (GameIngest + id + createdAt).
struct Game: Codable, Identifiable, Equatable {
    let id: String              // uuid
    let createdAt: Date         // date-time
    let date: Date              // format: date (calendar day)
    let opponent: String
    let location: String?       // nullable
    let periods: Int            // default 3, minimum 1
    let events: [GameEvent]
    let shifts: [Shift]
    let biometrics: BiometricSummary?

    init(from decoder: Decoder) throws {
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

    enum CodingKeys: String, CodingKey {
        case id, createdAt, date, opponent, location, periods, events, shifts, biometrics
    }
}
