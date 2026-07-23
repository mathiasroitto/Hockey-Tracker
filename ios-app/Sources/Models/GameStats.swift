import Foundation

/// Mirrors `#/components/schemas/GameStats`.
/// Derived numbers for a single game — computed by the server; the app only
/// displays them.
struct GameStats: Codable, Equatable {
    let gameId: String              // uuid
    let goals: Int
    let assists: Int
    let points: Int
    let shots: Int
    let shootingPct: Double         // goals / shots, 0..1
    let hits: Int
    let blocks: Int
    let penalties: Int
    let faceoffPct: Double          // wins / (wins+losses), 0..1
    let totalIceTimeSeconds: Double
    let shiftCount: Int
    let avgShiftSeconds: Double?     // optional in contract
    let biometrics: BiometricSummary?
}
