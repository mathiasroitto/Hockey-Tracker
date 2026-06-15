import Foundation

/// Keys and helpers shared by both sides of the WatchConnectivity bridge.
///
/// Finished games are sent watch -> phone as a file transfer (see
/// `WatchConnectivityManager`). A file transfer is used rather than a live
/// message because:
///   * it is queued and delivered reliably even if the phone is unreachable
///     when the game ends, and
///   * a full game (with thousands of heart-rate / speed samples) can be larger
///     than the limits of `sendMessage` / `transferUserInfo`.
enum SyncKey {
    /// Metadata attached to a finished-game file transfer.
    static let payloadType = "payloadType"
    static let gameID = "gameID"

    /// `userInfo` keys used for the lightweight "live" updates the watch sends
    /// while a game is in progress (best-effort, only when reachable).
    static let liveOpponent = "liveOpponent"
    static let liveStartDate = "liveStartDate"
    static let liveIsOnIce = "liveIsOnIce"
    static let liveShiftCount = "liveShiftCount"
    static let liveHeartRate = "liveHeartRate"
    static let liveEnded = "liveEnded"
}

enum SyncPayloadType: String {
    case finishedGame
}

extension Game {
    func encodedForSync() throws -> Data {
        try GameStore.encoder.encode(self)
    }

    static func decodeFromSync(_ data: Data) throws -> Game {
        try GameStore.decoder.decode(Game.self, from: data)
    }
}
