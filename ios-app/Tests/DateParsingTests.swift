import XCTest
import HockeyContract

/// Guards the interop contract between the server's variable-precision ISO-8601
/// timestamps and the app's `Date` decoding. Apple's `.withFractionalSeconds`
/// only accepts exactly three fractional digits, so anything else (6-digit
/// microseconds today, 3-digit milliseconds after the server change, or none)
/// must still decode.
///
/// Date parsing now lives in the shared `HockeyContract` package
/// (`ContractDate`); the app consumes it. The `normalizingFractionalSeconds`
/// helper is a package-internal implementation detail and is unit-tested in the
/// package's own suite — these tests cover the public `ContractDate.date(from:)`
/// entry point the app actually relies on.
final class DateParsingTests: XCTestCase {

    /// The same instant expressed with different fractional precision must parse
    /// to (approximately) the same `Date`.
    func testParsesFractionalPrecisionVariants() throws {
        let microseconds = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.110344Z"))
        let milliseconds = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.110Z"))
        let noFraction   = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59Z"))

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
        let short = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.11Z"))
        let long  = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.1103440Z"))
        let ref   = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.110Z"))

        XCTAssertEqual(short.timeIntervalSince1970, ref.timeIntervalSince1970, accuracy: 0.0005)
        XCTAssertEqual(long.timeIntervalSince1970, ref.timeIntervalSince1970, accuracy: 0.0005)
    }

    func testParsesNumericOffsetTimezone() throws {
        // Same instant via Z and via +00:00, with fractional seconds.
        let zulu   = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.110344Z"))
        let offset = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59.110344+00:00"))
        XCTAssertEqual(zulu.timeIntervalSince1970, offset.timeIntervalSince1970, accuracy: 0.0005)
    }

    func testParsesCalendarDate() throws {
        let day = try XCTUnwrap(ContractDate.date(from: "2026-07-23"))
        var utc = Calendar(identifier: .iso8601)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = utc.dateComponents([.year, .month, .day], from: day)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 23)
    }

    func testRejectsGarbage() {
        XCTAssertNil(ContractDate.date(from: "not-a-date"))
        XCTAssertNil(ContractDate.date(from: ""))
    }

    // MARK: round-trip helpers

    /// The calendar-day emitter round-trips through the parser.
    func testCalendarStringRoundTrips() throws {
        let day = try XCTUnwrap(ContractDate.date(from: "2026-07-23"))
        XCTAssertEqual(ContractDate.calendarString(from: day), "2026-07-23")
    }

    /// The instant emitter produces compact ISO-8601 UTC the parser accepts.
    func testInstantStringRoundTrips() throws {
        let instant = try XCTUnwrap(ContractDate.date(from: "2026-07-23T22:40:59Z"))
        let emitted = ContractDate.instantString(from: instant)
        XCTAssertEqual(emitted, "2026-07-23T22:40:59Z")
        let reparsed = try XCTUnwrap(ContractDate.date(from: emitted))
        XCTAssertEqual(reparsed.timeIntervalSince1970,
                       instant.timeIntervalSince1970,
                       accuracy: 0.0005)
    }
}
