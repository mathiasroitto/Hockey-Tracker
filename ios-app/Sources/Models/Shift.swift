import Foundation

/// Mirrors `#/components/schemas/Shift`.
struct Shift: Codable, Identifiable, Equatable {
    let id: String              // uuid
    let periodNumber: Int       // minimum 1
    let startTime: Date         // date-time
    let durationSeconds: Double // number, minimum 0
}
