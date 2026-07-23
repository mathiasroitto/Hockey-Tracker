import Foundation

/// JSON encoder/decoder configured to match the server contract
/// (`contract/openapi.yaml`).
///
/// Contract conventions honored here:
/// - Timestamps (`date-time`) are ISO-8601 UTC. The Watch *emits* the compact
///   form (`2026-07-23T18:04:11Z`) via the encoder's `.iso8601` strategy, but
///   the server *emits* fractional seconds (e.g. `2026-07-23T22:40:59.110Z`).
///   Foundation's built-in `.iso8601` decode strategy rejects fractional
///   seconds outright, so the decoder uses a lenient custom strategy that
///   accepts any fractional precision (none / 3-digit / 6-digit) — plus the
///   `yyyy-MM-dd` calendar date form — for safety if a `Date` field ever
///   decodes a server-produced timestamp.
/// - Calendar dates (`format: date`, e.g. the game `date`) are modeled as
///   `String` values so they serialize exactly as `yyyy-MM-dd` — see
///   `GameDateFormatting`.
/// - Durations are plain numbers in seconds.
/// - `nil` optionals are omitted (the server treats absent and `null` the same
///   for the nullable contract fields).
enum ContractJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Outgoing timestamps stay in the compact ISO-8601 UTC form.
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ContractDateParsing.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return decoder
    }()
}

/// Lenient parsing for the date/date-time string forms the contract may present.
///
/// Handles, in order:
/// - ISO-8601 UTC with fractional seconds: `2026-07-23T22:40:59.110Z`,
///   `2026-07-23T22:40:59.110250Z` (any fractional precision).
/// - ISO-8601 UTC without fractional seconds: `2026-07-23T18:04:11Z`.
/// - Calendar date only: `2026-07-23`.
enum ContractDateParsing {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from string: String) -> Date? {
        // `ISO8601DateFormatter` with `.withFractionalSeconds` only accepts a
        // fixed 3-digit fraction, so normalize any other precision to millis.
        if let normalized = normalizedFractional(string),
           let date = fractional.date(from: normalized) {
            return date
        }
        if let date = plain.date(from: string) {
            return date
        }
        return dateOnly.date(from: string)
    }

    /// Rewrites the fractional-seconds component to exactly 3 digits (padding or
    /// truncating) so `ISO8601DateFormatter` can parse it. Returns `nil` when
    /// there is no fractional component to normalize.
    private static func normalizedFractional(_ string: String) -> String? {
        guard let dotIndex = string.firstIndex(of: ".") else { return nil }
        let afterDot = string.index(after: dotIndex)
        // Collect the run of fractional digits.
        var digitsEnd = afterDot
        while digitsEnd < string.endIndex, string[digitsEnd].isNumber {
            digitsEnd = string.index(after: digitsEnd)
        }
        let digits = string[afterDot..<digitsEnd]
        guard !digits.isEmpty else { return nil }
        var millis = String(digits.prefix(3))
        while millis.count < 3 { millis += "0" }
        return String(string[..<afterDot]) + millis + String(string[digitsEnd...])
    }
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
