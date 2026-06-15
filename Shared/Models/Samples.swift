import Foundation

/// A single heart-rate reading, in beats per minute.
struct HeartRateSample: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var bpm: Double

    init(id: UUID = UUID(), date: Date = Date(), bpm: Double) {
        self.id = id
        self.date = date
        self.bpm = bpm
    }
}

/// A single speed reading, in meters per second (from CoreLocation).
struct SpeedSample: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    /// Speed in meters per second. Negative values from CoreLocation (meaning
    /// "invalid") are never stored.
    var speed: Double

    init(id: UUID = UUID(), date: Date = Date(), speed: Double) {
        self.id = id
        self.date = date
        self.speed = speed
    }
}

extension Double {
    /// meters/second -> kilometers/hour
    var metersPerSecondToKmh: Double { self * 3.6 }
    /// meters/second -> miles/hour
    var metersPerSecondToMph: Double { self * 2.2369362921 }
}
