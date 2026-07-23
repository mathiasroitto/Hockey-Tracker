import Foundation

/// Shared JSON coders configured to match the server (FastAPI / Pydantic).
///
/// The contract uses two temporal shapes:
///   * `date-time` — ISO-8601 UTC instants (e.g. `createdAt`, `timestamp`,
///     `startTime`). Python may emit these with or without fractional seconds
///     and with either `Z` or `+00:00` offsets.
///   * `date` — a plain calendar day, `yyyy-MM-dd` (the game `date`).
///
/// A single `Date` decoding strategy has to accept all of these, so we try a
/// chain of formatters and pick the first that parses.
enum JSONCoding {

    /// Decoder for all server responses.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = DateParsing.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date string: \(raw)"
            )
        }
        return decoder
    }()

    /// Encoder for request bodies the app sends (currently only `UserUpdate`,
    /// and optionally a relayed `GameIngest`).
    ///
    /// `date-time` values are encoded as ISO-8601 UTC with fractional seconds.
    /// Calendar-date encoding is intentionally not attempted here: the only
    /// body the app sends today (`UserUpdate`) carries no dates. If GameIngest
    /// relay is added, encode its `date` field explicitly as `yyyy-MM-dd`.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateParsing.isoUTCString(from: date))
        }
        return encoder
    }()
}

enum DateParsing {

    /// Full ISO-8601 with fractional seconds, e.g. 2026-07-23T12:34:56.789Z
    ///
    /// NOTE: `ISO8601DateFormatter` with `.withFractionalSeconds` accepts
    /// *exactly three* fractional digits. The server may emit any precision
    /// (6-digit microseconds today, 3-digit milliseconds after the change, or
    /// none at all), so callers must normalize the fractional part to three
    /// digits before handing a string to this formatter — see
    /// `normalizingFractionalSeconds(_:toDigits:)`.
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO-8601 without fractional seconds, e.g. 2026-07-23T12:34:56Z
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Calendar date only, e.g. 2026-07-23. Interpreted at UTC midnight.
    private static let calendarDate: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Parses an ISO-8601 UTC `date-time` of ANY fractional-second precision
    /// (none, 3-digit ms, 6-digit µs, or anything else) and the `yyyy-MM-dd`
    /// game `date`.
    ///
    /// The strategy does not rely on a single strict formatter. It tries, in
    /// order:
    ///   1. the string normalized to exactly 3 fractional digits, parsed as a
    ///      fractional `date-time`;
    ///   2. the string with any fractional part stripped, parsed as a plain
    ///      `date-time`;
    ///   3. a date-only `yyyy-MM-dd`.
    static func date(from string: String) -> Date? {
        // Fractional date-time: pad/truncate the fractional part to 3 digits so
        // `.withFractionalSeconds` (which requires exactly 3) can parse it.
        if let normalized = normalizingFractionalSeconds(string, toDigits: 3),
           let d = isoWithFractional.date(from: normalized) {
            return d
        }
        // Non-fractional date-time: strip any fractional part entirely.
        if let stripped = normalizingFractionalSeconds(string, toDigits: 0),
           let d = isoPlain.date(from: stripped) {
            return d
        }
        // Date-only calendar day.
        if let d = calendarDate.date(from: string) { return d }
        return nil
    }

    /// Rewrites the fractional-seconds component of an ISO-8601 `date-time` to a
    /// fixed width, leaving the date, time, and timezone designator untouched.
    ///
    /// - `toDigits: 3` pads or truncates the fraction to three digits; if there
    ///   is no fractional part, one is *not* inserted (returns `nil` so callers
    ///   fall through to the non-fractional path).
    /// - `toDigits: 0` removes the fractional part (dot included); if there is
    ///   none, the string is returned unchanged.
    ///
    /// Only a `.` immediately followed by digits is treated as the fraction.
    /// ISO-8601 date-times contain no other `.`, so this is unambiguous, and it
    /// handles both `Z` and `+00:00`/`-05:00` offsets since the timezone tail is
    /// preserved verbatim.
    ///
    /// Examples:
    ///   `2026-07-23T22:40:59.110344Z`, toDigits: 3 -> `2026-07-23T22:40:59.110Z`
    ///   `2026-07-23T22:40:59.11Z`,     toDigits: 3 -> `2026-07-23T22:40:59.110Z`
    ///   `2026-07-23T22:40:59.110344Z`, toDigits: 0 -> `2026-07-23T22:40:59Z`
    ///   `2026-07-23T22:40:59Z`,        toDigits: 0 -> `2026-07-23T22:40:59Z`
    ///   `2026-07-23T22:40:59Z`,        toDigits: 3 -> nil
    static func normalizingFractionalSeconds(_ string: String, toDigits count: Int) -> String? {
        guard let dotRange = string.range(of: #"\.[0-9]+"#, options: .regularExpression) else {
            // No fractional part present.
            return count == 0 ? string : nil
        }
        if count == 0 {
            return string.replacingCharacters(in: dotRange, with: "")
        }
        let digits = string[dotRange].dropFirst() // drop the leading "."
        let fraction: String
        if digits.count >= count {
            fraction = String(digits.prefix(count))
        } else {
            fraction = digits + String(repeating: "0", count: count - digits.count)
        }
        return string.replacingCharacters(in: dotRange, with: "." + fraction)
    }

    static func isoUTCString(from date: Date) -> String {
        isoWithFractional.string(from: date)
    }

    /// Formats a `Date` back to `yyyy-MM-dd` (UTC) — used when displaying the
    /// game's calendar date and if a GameIngest relay ever encodes it.
    static func calendarString(from date: Date) -> String {
        calendarDate.string(from: date)
    }
}
