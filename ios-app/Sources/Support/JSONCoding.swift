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

    static func date(from string: String) -> Date? {
        if let d = isoWithFractional.date(from: string) { return d }
        if let d = isoPlain.date(from: string) { return d }
        if let d = calendarDate.date(from: string) { return d }
        return nil
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
