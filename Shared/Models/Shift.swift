import Foundation

/// A single shift — one stretch of time the player spends on the ice.
///
/// A shift is started/ended by the player tapping the on-ice button on the
/// watch. We only store the start/end timestamps here; everything else
/// (average heart rate during the shift, heart-rate recovery on the bench
/// afterwards, top speed, etc.) is reconstructed from the game's sample series
/// by `GameStatistics`.
struct Shift: Codable, Identifiable, Equatable {
    var id: UUID
    var startDate: Date
    /// `nil` while the player is still on the ice for this shift.
    var endDate: Date?

    init(id: UUID = UUID(), startDate: Date = Date(), endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    var isActive: Bool { endDate == nil }

    /// Length of the shift. Uses "now" while the shift is still active so the
    /// UI can show a live-updating timer.
    var duration: TimeInterval {
        (endDate ?? Date()).timeIntervalSince(startDate)
    }
}
