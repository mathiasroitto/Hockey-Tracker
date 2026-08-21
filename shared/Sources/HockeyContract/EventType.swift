import Foundation

/// Mirrors `#/components/schemas/EventType`.
///
/// A tracked in-game event. Raw values are the exact wire strings the server
/// expects — do not rename without a contract change. Unknown future values
/// decode to `.unknown` rather than failing the whole response
/// (forward-compatibility); producers use ``loggable`` and never emit it.
public enum EventType: String, Codable, CaseIterable, Identifiable, Hashable {
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

    public var id: String { rawValue }

    /// The events a client can produce — every case except the forward-compat
    /// `.unknown` sentinel. Build capture UI from this, not `allCases`.
    public static let loggable: [EventType] = allCases.filter { $0 != .unknown }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = EventType(rawValue: raw) ?? .unknown
    }

    /// Human-readable label for display.
    public var displayLabel: String {
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
