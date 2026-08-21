import Foundation

/// JSON coders configured to match the server (`contract/openapi.yaml`).
///
/// - `date-time` (instants like `createdAt`, `timestamp`, `startTime`): decoded
///   from ISO-8601 UTC of *any* fractional precision; encoded as compact
///   ISO-8601 UTC (`2026-07-23T18:04:11Z`), which the server accepts.
/// - `date` (the calendar-day game `date`): handled by the models themselves
///   (`GameIngest`/`Game` code it explicitly as `yyyy-MM-dd`); the decoder's
///   lenient strategy also accepts that form.
public enum ContractJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ContractDate.instantString(from: date))
        }
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ContractDate.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date string: \(raw)"
            )
        }
        return decoder
    }()
}

/// Date/time formatting and lenient parsing for the contract's temporal forms.
public enum ContractDate {

    /// Full ISO-8601 with fractional seconds. NOTE: `.withFractionalSeconds`
    /// accepts *exactly three* fractional digits, so callers normalize first.
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO-8601 without fractional seconds, e.g. 2026-07-23T12:34:56Z.
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Calendar date only, `yyyy-MM-dd`, interpreted at UTC midnight.
    private static let calendar: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Emit an instant (`date-time`) as compact ISO-8601 UTC.
    public static func instantString(from date: Date) -> String {
        isoPlain.string(from: date)
    }

    /// Emit a calendar day as `yyyy-MM-dd` (UTC). Used for the game `date` and
    /// for the `from`/`to` query parameters on `GET /games`.
    public static func calendarString(from date: Date) -> String {
        calendar.string(from: date)
    }

    /// Parse an ISO-8601 UTC `date-time` of ANY fractional-second precision
    /// (none, 3-digit ms, 6-digit µs, …) or a `yyyy-MM-dd` calendar day.
    public static func date(from string: String) -> Date? {
        // Fractional date-time: normalize the fraction to exactly 3 digits.
        if let normalized = normalizingFractionalSeconds(string, toDigits: 3),
           let d = isoFractional.date(from: normalized) {
            return d
        }
        // Non-fractional date-time: strip any fractional part.
        if let stripped = normalizingFractionalSeconds(string, toDigits: 0),
           let d = isoPlain.date(from: stripped) {
            return d
        }
        // Calendar day.
        return calendar.date(from: string)
    }

    /// Rewrites the fractional-seconds component of an ISO-8601 `date-time` to a
    /// fixed width, leaving date, time, and timezone designator untouched.
    ///
    /// - `toDigits: 3` pads/truncates to three digits; returns `nil` if there is
    ///   no fractional part (callers fall through to the non-fractional path).
    /// - `toDigits: 0` removes the fractional part; if there is none the string
    ///   is returned unchanged.
    static func normalizingFractionalSeconds(_ string: String, toDigits count: Int) -> String? {
        guard let dotRange = string.range(of: #"\.[0-9]+"#, options: .regularExpression) else {
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
}
