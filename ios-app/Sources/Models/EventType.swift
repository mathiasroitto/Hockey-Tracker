import Foundation

/// Mirrors `#/components/schemas/EventType`.
/// A tracked in-game event. Unknown future values decode to `.unknown` rather
/// than failing the whole response (forward-compatibility with the contract).
enum EventType: String, Codable, CaseIterable, Equatable {
    case goal
    case assist
    case shot
    case hit
    case block
    case penalty
    case faceoffWin = "faceoff_win"
    case faceoffLoss = "faceoff_loss"
    case takeaway
    case giveaway
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = EventType(rawValue: raw) ?? .unknown
    }

    /// Human-readable label for display.
    var displayLabel: String {
        switch self {
        case .goal: return "Goal"
        case .assist: return "Assist"
        case .shot: return "Shot"
        case .hit: return "Hit"
        case .block: return "Block"
        case .penalty: return "Penalty"
        case .faceoffWin: return "Faceoff Win"
        case .faceoffLoss: return "Faceoff Loss"
        case .takeaway: return "Takeaway"
        case .giveaway: return "Giveaway"
        case .unknown: return "Unknown"
        }
    }
}
