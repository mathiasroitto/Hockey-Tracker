import XCTest
@testable import HockeyContract

final class HockeyContractTests: XCTestCase {

    // MARK: EventType

    func testEventTypeWireStrings() throws {
        XCTAssertEqual(EventType.faceoffWin.rawValue, "faceoff_win")
        XCTAssertEqual(EventType.faceoffLoss.rawValue, "faceoff_loss")
    }

    func testEventTypeUnknownFallback() throws {
        let decoded = try ContractJSON.decoder.decode(EventType.self, from: Data("\"time_travel\"".utf8))
        XCTAssertEqual(decoded, .unknown)
    }

    func testLoggableExcludesUnknown() {
        XCTAssertFalse(EventType.loggable.contains(.unknown))
        XCTAssertEqual(EventType.loggable.count, EventType.allCases.count - 1)
    }

    // MARK: Lenient date parsing (any fractional precision + calendar day)

    func testLenientDateParsing() {
        XCTAssertNotNil(ContractDate.date(from: "2026-07-23T22:40:59.110Z"))    // 3-digit ms
        XCTAssertNotNil(ContractDate.date(from: "2026-07-23T22:40:59.110344Z")) // 6-digit µs
        XCTAssertNotNil(ContractDate.date(from: "2026-07-23T22:40:59Z"))        // no fraction
        XCTAssertNotNil(ContractDate.date(from: "2026-07-23"))                  // calendar day
        XCTAssertNil(ContractDate.date(from: "not-a-date"))
    }

    // MARK: GameIngest — date as yyyy-MM-dd, timestamps as instants

    func testGameIngestDateEncodesAsCalendarDay() throws {
        let day = ContractDate.date(from: "2026-07-23")!
        let ingest = GameIngest(
            date: day,
            opponent: "Rival HC",
            events: [GameEvent(type: .goal, periodNumber: 1,
                               timestamp: ContractDate.date(from: "2026-07-23T18:04:11Z")!)],
            shifts: [Shift(periodNumber: 1,
                           startTime: ContractDate.date(from: "2026-07-23T18:00:00Z")!,
                           durationSeconds: 45)]
        )
        let json = String(data: try ContractJSON.encoder.encode(ingest), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"date\":\"2026-07-23\""), json)        // calendar day
        XCTAssertTrue(json.contains("2026-07-23T18:04:11Z"), json)           // instant preserved

        // Round-trips back to an equal value.
        let decoded = try ContractJSON.decoder.decode(GameIngest.self,
                                                       from: try ContractJSON.encoder.encode(ingest))
        XCTAssertEqual(decoded, ingest)
    }

    func testGameIngestDefaultsPeriodsToThree() throws {
        let json = """
        {"date":"2026-07-23","opponent":"Rival HC","events":[],"shifts":[]}
        """
        let decoded = try ContractJSON.decoder.decode(GameIngest.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.periods, 3)
    }

    // MARK: UserUpdate — omit vs explicit null

    func testUserUpdateOmitsWhenNone() throws {
        let json = String(data: try ContractJSON.encoder.encode(UserUpdate()), encoding: .utf8)!
        XCTAssertFalse(json.contains("displayName"))
    }

    func testUserUpdateEmitsNullWhenSomeNil() throws {
        let json = String(data: try ContractJSON.encoder.encode(UserUpdate(displayName: .some(nil))),
                          encoding: .utf8)!
        XCTAssertTrue(json.contains("\"displayName\":null"), json)
    }

    func testUserUpdateSetsValue() throws {
        let json = String(data: try ContractJSON.encoder.encode(UserUpdate(displayName: "Mathias")),
                          encoding: .utf8)!
        XCTAssertTrue(json.contains("\"displayName\":\"Mathias\""), json)
    }
}
