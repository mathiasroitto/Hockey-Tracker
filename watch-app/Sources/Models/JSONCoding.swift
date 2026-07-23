import Foundation

/// JSON encoder/decoder configured to match the server contract
/// (`contract/openapi.yaml`).
///
/// Contract conventions honored here:
/// - Timestamps (`date-time`) are ISO-8601 UTC (e.g. `2026-07-23T18:04:11Z`).
///   Handled by `.iso8601` for every `Date` field (`timestamp`, `startTime`).
/// - Calendar dates (`format: date`, e.g. the game `date`) are modeled as
///   `String` values so they serialize exactly as `yyyy-MM-dd` — see
///   `GameDateFormatting`.
/// - Durations are plain numbers in seconds.
/// - `nil` optionals are omitted (the server treats absent and `null` the same
///   for the nullable contract fields).
enum ContractJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// Formats a `Date` as a contract `date` (calendar date, `yyyy-MM-dd`) in UTC.
enum GameDateFormatting {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
