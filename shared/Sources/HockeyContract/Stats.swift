import Foundation

/// Mirrors `#/components/schemas/GameStats`.
/// Derived numbers for a single game — computed by the server; clients display.
public struct GameStats: Codable, Equatable {
    public let gameId: String
    public let goals: Int
    public let assists: Int
    public let points: Int
    public let shots: Int
    /// goals / shots, 0..1.
    public let shootingPct: Double
    public let hits: Int
    public let blocks: Int
    public let penalties: Int
    /// wins / (wins + losses), 0..1.
    public let faceoffPct: Double
    public let totalIceTimeSeconds: Double
    public let shiftCount: Int
    /// Optional in the contract.
    public let avgShiftSeconds: Double?
    public let biometrics: BiometricSummary?

    public init(
        gameId: String,
        goals: Int,
        assists: Int,
        points: Int,
        shots: Int,
        shootingPct: Double,
        hits: Int,
        blocks: Int,
        penalties: Int,
        faceoffPct: Double,
        totalIceTimeSeconds: Double,
        shiftCount: Int,
        avgShiftSeconds: Double? = nil,
        biometrics: BiometricSummary? = nil
    ) {
        self.gameId = gameId
        self.goals = goals
        self.assists = assists
        self.points = points
        self.shots = shots
        self.shootingPct = shootingPct
        self.hits = hits
        self.blocks = blocks
        self.penalties = penalties
        self.faceoffPct = faceoffPct
        self.totalIceTimeSeconds = totalIceTimeSeconds
        self.shiftCount = shiftCount
        self.avgShiftSeconds = avgShiftSeconds
        self.biometrics = biometrics
    }
}

/// Mirrors `#/components/schemas/CareerStats`.
/// Totals and per-game averages across every game — computed by the server.
public struct CareerStats: Codable, Equatable {
    public let gamesPlayed: Int
    public let totalGoals: Int
    public let totalAssists: Int
    public let totalPoints: Int
    /// Optional in the contract.
    public let totalShots: Int?
    /// Optional in the contract.
    public let shootingPct: Double?
    public let pointsPerGame: Double
    /// Optional in the contract.
    public let avgIceTimeSeconds: Double?

    public init(
        gamesPlayed: Int,
        totalGoals: Int,
        totalAssists: Int,
        totalPoints: Int,
        totalShots: Int? = nil,
        shootingPct: Double? = nil,
        pointsPerGame: Double,
        avgIceTimeSeconds: Double? = nil
    ) {
        self.gamesPlayed = gamesPlayed
        self.totalGoals = totalGoals
        self.totalAssists = totalAssists
        self.totalPoints = totalPoints
        self.totalShots = totalShots
        self.shootingPct = shootingPct
        self.pointsPerGame = pointsPerGame
        self.avgIceTimeSeconds = avgIceTimeSeconds
    }
}
