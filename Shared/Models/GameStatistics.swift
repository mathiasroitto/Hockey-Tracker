import Foundation

/// Per-shift derived numbers, computed from the game's raw sample series.
struct ShiftStatistics: Identifiable, Equatable {
    /// Stable id (matches the underlying `Shift.id`).
    var id: UUID
    /// 1-based shift number within the game.
    var number: Int
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval

    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Heart rate at the moment the player came off the ice.
    var endHeartRate: Double?

    /// Heart rate measured ~`recoveryWindow` seconds into the rest that
    /// followed this shift.
    var recoveryHeartRate: Double?
    /// How many bpm the heart rate dropped during recovery
    /// (`endHeartRate - recoveryHeartRate`). Larger is fitter.
    var recoveryDrop: Double?

    var maxSpeed: Double?
}

/// Computes all the summary numbers shown in the app from a `Game`'s raw data.
///
/// Keeping this separate from `Game` means the stored data is just the lossless
/// recording; every statistic can be re-derived (and improved) later without a
/// data migration.
struct GameStatistics: Equatable {
    /// Window after a shift over which we look for heart-rate recovery.
    static let recoveryWindow: TimeInterval = 60

    let totalDuration: TimeInterval
    let shiftCount: Int
    let totalIceTime: TimeInterval
    let totalRestTime: TimeInterval
    let averageShiftLength: TimeInterval
    let longestShift: TimeInterval
    let shortestShift: TimeInterval

    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    /// Average heart-rate recovery drop across all completed shifts.
    let averageRecoveryDrop: Double?

    let maxSpeed: Double?
    let averageSpeed: Double?
    let totalDistance: Double
    let activeEnergyBurned: Double

    let shifts: [ShiftStatistics]

    init(game: Game) {
        let end = game.endDate ?? Date()
        totalDuration = end.timeIntervalSince(game.startDate)

        // ---- Shifts ----------------------------------------------------
        let hr = game.heartRateSamples.sorted { $0.date < $1.date }
        let completedShifts = game.shifts.sorted { $0.startDate < $1.startDate }

        var shiftStats: [ShiftStatistics] = []
        for (index, shift) in completedShifts.enumerated() {
            let shiftEnd = shift.endDate ?? end
            let inShift = hr.filter { $0.date >= shift.startDate && $0.date <= shiftEnd }
            let bpms = inShift.map(\.bpm)

            // Recovery: compare HR at end of shift with HR ~recoveryWindow
            // seconds later (only meaningful for shifts that actually ended).
            var recoveryHR: Double?
            var endHR: Double?
            if let realEnd = shift.endDate {
                endHR = hr.last(where: { $0.date <= realEnd })?.bpm
                let target = realEnd.addingTimeInterval(Self.recoveryWindow)
                recoveryHR = hr
                    .filter { $0.date > realEnd && $0.date <= target }
                    .max(by: { $0.date < $1.date })?
                    .bpm
            }
            var drop: Double?
            if let e = endHR, let r = recoveryHR { drop = e - r }

            let speedsInShift = game.speedSamples
                .filter { $0.date >= shift.startDate && $0.date <= shiftEnd }
                .map(\.speed)

            shiftStats.append(
                ShiftStatistics(
                    id: shift.id,
                    number: index + 1,
                    startDate: shift.startDate,
                    endDate: shift.endDate,
                    duration: shift.duration,
                    averageHeartRate: bpms.isEmpty ? nil : bpms.reduce(0, +) / Double(bpms.count),
                    maxHeartRate: bpms.max(),
                    endHeartRate: endHR,
                    recoveryHeartRate: recoveryHR,
                    recoveryDrop: drop,
                    maxSpeed: speedsInShift.max()
                )
            )
        }
        shifts = shiftStats

        shiftCount = completedShifts.count
        let durations = completedShifts.map(\.duration)
        totalIceTime = durations.reduce(0, +)
        totalRestTime = max(0, totalDuration - totalIceTime)
        averageShiftLength = durations.isEmpty ? 0 : totalIceTime / Double(durations.count)
        longestShift = durations.max() ?? 0
        shortestShift = durations.min() ?? 0

        // ---- Heart rate ------------------------------------------------
        let allBpm = hr.map(\.bpm)
        averageHeartRate = allBpm.isEmpty ? nil : allBpm.reduce(0, +) / Double(allBpm.count)
        maxHeartRate = allBpm.max()
        minHeartRate = allBpm.min()
        let drops = shiftStats.compactMap(\.recoveryDrop)
        averageRecoveryDrop = drops.isEmpty ? nil : drops.reduce(0, +) / Double(drops.count)

        // ---- Speed -----------------------------------------------------
        let speeds = game.speedSamples.map(\.speed)
        maxSpeed = speeds.max()
        averageSpeed = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)

        totalDistance = game.totalDistance
        activeEnergyBurned = game.activeEnergyBurned
    }
}
