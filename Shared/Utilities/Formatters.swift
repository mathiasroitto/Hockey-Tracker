import Foundation

/// Shared formatting helpers so the watch and phone display values identically.
enum Format {
    /// `83:12` style mm:ss (or `1:05:30` when over an hour).
    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Compact `1m 23s` style, used for shift lengths in lists.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        if minutes == 0 { return "\(seconds)s" }
        return "\(minutes)m \(seconds)s"
    }

    static func bpm(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))"
    }

    /// Speed in km/h with one decimal.
    static func speedKmh(_ metersPerSecond: Double?) -> String {
        guard let metersPerSecond else { return "--" }
        return String(format: "%.1f", metersPerSecond.metersPerSecondToKmh)
    }

    /// Distance in km (or meters under 1 km).
    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return String(format: "%.0f m", meters) }
        return String(format: "%.2f km", meters / 1000)
    }

    static func energy(_ kilocalories: Double) -> String {
        String(format: "%.0f kcal", kilocalories)
    }

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
