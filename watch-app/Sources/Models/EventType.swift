import Foundation

/// A tracked in-game event.
///
/// Mirrors `EventType` in `contract/openapi.yaml`. Raw values are the exact
/// wire strings the server expects — do not rename without a contract change.
enum EventType: String, Codable, CaseIterable, Identifiable, Hashable {
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

    var id: String { rawValue }
}
