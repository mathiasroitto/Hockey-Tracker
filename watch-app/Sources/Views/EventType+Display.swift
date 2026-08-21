import SwiftUI
import HockeyContract

/// UI presentation for `EventType`, kept out of the model so the model stays a
/// pure contract mirror.
extension EventType {
    /// Short, glove-legible button label.
    var shortLabel: String {
        switch self {
        case .goal: return "Goal"
        case .assist: return "Assist"
        case .shot: return "Shot"
        case .hit: return "Hit"
        case .block: return "Block"
        case .penalty: return "PIM"
        case .faceoffWin: return "FO W"
        case .faceoffLoss: return "FO L"
        case .takeaway: return "Takeaway"
        case .giveaway: return "Giveaway"
        case .unknown: return "?"
        }
    }

    var tint: Color {
        switch self {
        case .goal: return .green
        case .assist: return .mint
        case .shot: return .blue
        case .hit: return .orange
        case .block: return .teal
        case .penalty: return .red
        case .faceoffWin: return .indigo
        case .faceoffLoss: return .purple
        case .takeaway: return .cyan
        case .giveaway: return .brown
        case .unknown: return .gray
        }
    }
}

/// Order of the button grid — most-tapped events first.
enum EventButtonLayout {
    static let ordered: [EventType] = [
        .goal, .assist, .shot,
        .hit, .block, .penalty,
        .faceoffWin, .faceoffLoss,
        .takeaway, .giveaway
    ]

    /// Key events shown in the live counter row.
    static let counters: [EventType] = [.goal, .assist, .shot]
}

/// Formats a duration in seconds as `m:ss`.
func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
