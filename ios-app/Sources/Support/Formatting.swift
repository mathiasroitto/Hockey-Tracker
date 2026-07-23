import Foundation

/// Display formatters shared across views. Pure presentation — no stats math
/// happens here; the server computes all derived numbers.
enum Format {

    /// e.g. "Jul 23, 2026" for a game's calendar date. Dates decode at UTC
    /// midnight, so format in UTC to avoid a day-boundary shift.
    static func gameDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// "12:34" (mm:ss) or "1:02:03" for ice-time / shift durations in seconds.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// A 0..1 ratio as a percentage, e.g. 0.125 → "12.5%".
    static func percent(_ ratio: Double) -> String {
        guard ratio.isFinite else { return "—" }
        return String(format: "%.1f%%", ratio * 100)
    }

    /// A rounded number, e.g. 72.4 → "72".
    static func rounded(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(Int(value.rounded()))
    }

    /// One decimal place, e.g. points-per-game 1.25 → "1.3".
    static func oneDecimal(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%.1f", value)
    }
}
