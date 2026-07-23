import Foundation

/// Mirrors `#/components/schemas/GameEvent`.
struct GameEvent: Codable, Identifiable, Equatable {
    let id: String            // uuid
    let type: EventType
    let periodNumber: Int     // minimum 1
    let timestamp: Date       // date-time, ISO-8601 UTC
    let note: String?         // nullable
}
