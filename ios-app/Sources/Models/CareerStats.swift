import Foundation

/// Mirrors `#/components/schemas/CareerStats`.
/// Totals and per-game averages across every game — computed by the server.
struct CareerStats: Codable, Equatable {
    let gamesPlayed: Int
    let totalGoals: Int
    let totalAssists: Int
    let totalPoints: Int
    let totalShots: Int?            // optional in contract
    let shootingPct: Double?        // optional in contract
    let pointsPerGame: Double
    let avgIceTimeSeconds: Double?  // optional in contract
}
