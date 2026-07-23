import XCTest
@testable import HockeyTracker

/// Guards the interop contract between the server's variable-precision ISO-8601
/// timestamps and the app's `Date` decoding. Apple's `.withFractionalSeconds`
/// only accepts exactly three fractional digits, so anything else (6-digit
/// microseconds today, 3-digit milliseconds after the server change, or none)
/// must still decode.
final class DateParsingTests: XCTestCase {

    /// The same instant expressed with different fractional precision must parse
    /// to (approximately) the same `Date`.
    func testParsesFractionalPrecisionVariants() throws {
        let microseconds = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.110344Z"))
        let milliseconds = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.110Z"))
        let noFraction   = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59Z"))

        // ms and µs round to the same millisecond boundary this formatter keeps.
        XCTAssertEqual(microseconds.timeIntervalSince1970,
                       milliseconds.timeIntervalSince1970,
                       accuracy: 0.0005)
        // The whole-second value should sit within a second of the fractional one.
        XCTAssertEqual(floor(milliseconds.timeIntervalSince1970),
                       noFraction.timeIntervalSince1970,
                       accuracy: 0.0001)
    }

    func testParsesShortAndLongFractions() throws {
        // Two-digit fraction (padded to .110) and seven-digit fraction (truncated).
        let short = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.11Z"))
        let long  = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.1103440Z"))
        let ref   = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.110Z"))

        XCTAssertEqual(short.timeIntervalSince1970, ref.timeIntervalSince1970, accuracy: 0.0005)
        XCTAssertEqual(long.timeIntervalSince1970, ref.timeIntervalSince1970, accuracy: 0.0005)
    }

    func testParsesNumericOffsetTimezone() throws {
        // Same instant via Z and via +00:00, with fractional seconds.
        let zulu   = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.110344Z"))
        let offset = try XCTUnwrap(DateParsing.date(from: "2026-07-23T22:40:59.110344+00:00"))
        XCTAssertEqual(zulu.timeIntervalSince1970, offset.timeIntervalSince1970, accuracy: 0.0005)
    }

    func testParsesCalendarDate() throws {
        let day = try XCTUnwrap(DateParsing.date(from: "2026-07-23"))
        var utc = Calendar(identifier: .iso8601)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = utc.dateComponents([.year, .month, .day], from: day)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 23)
    }

    func testRejectsGarbage() {
        XCTAssertNil(DateParsing.date(from: "not-a-date"))
        XCTAssertNil(DateParsing.date(from: ""))
    }

    // MARK: normalizingFractionalSeconds

    func testNormalizePadsAndTruncatesToThree() {
        XCTAssertEqual(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59.110344Z", toDigits: 3),
            "2026-07-23T22:40:59.110Z")
        XCTAssertEqual(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59.11Z", toDigits: 3),
            "2026-07-23T22:40:59.110Z")
        // No fractional part -> nil so callers fall through to the plain path.
        XCTAssertNil(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59Z", toDigits: 3))
    }

    func testNormalizeStripsFraction() {
        XCTAssertEqual(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59.110344Z", toDigits: 0),
            "2026-07-23T22:40:59Z")
        // No fractional part -> unchanged.
        XCTAssertEqual(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59Z", toDigits: 0),
            "2026-07-23T22:40:59Z")
    }

    func testNormalizePreservesOffset() {
        XCTAssertEqual(
            DateParsing.normalizingFractionalSeconds("2026-07-23T22:40:59.110344+02:00", toDigits: 3),
            "2026-07-23T22:40:59.110+02:00")
    }
}
