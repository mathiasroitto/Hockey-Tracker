import Foundation

/// A single logged in-game event.
///
/// Mirrors `GameEvent` in `contract/openapi.yaml`.
/// Required: `id`, `type`, `periodNumber`, `timestamp`.
struct GameEvent: Codable, Identifiable, Hashable {
    /// UUID string.
    let id: String
    let type: EventType
    /// 1-based period number (contract minimum: 1).
    let periodNumber: Int
    /// ISO-8601 UTC instant the event occurred.
    let timestamp: Date
    /// Optional free-text note (contract nullable).
    var note: String?

    init(
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
