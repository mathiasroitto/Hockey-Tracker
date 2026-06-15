import Foundation
import WatchConnectivity

/// Watch side of the phone <-> watch bridge.
///
/// * Finished games are sent with `transferFile`, which is queued and delivered
///   reliably even if the phone is not currently reachable (e.g. left at home).
/// * While a game is in progress, lightweight "live" updates are sent with
///   `sendMessage` *only when the phone is reachable* — these are best-effort so
///   the phone can show a "game in progress" glance, and are safe to drop.
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    private var session: WCSession { .default }

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// Queue a finished game for delivery to the phone.
    func send(finishedGame game: Game) {
        guard WCSession.isSupported() else { return }
        do {
            let data = try game.encodedForSync()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("game-\(game.id.uuidString).json")
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: [
                SyncKey.payloadType: SyncPayloadType.finishedGame.rawValue,
                SyncKey.gameID: game.id.uuidString
            ])
        } catch {
            // If encoding/writing fails the game is still safe on the watch and
            // can be re-sent later.
        }
    }

    /// Best-effort live snapshot (only sent when the phone is reachable).
    func sendLiveUpdate(for game: Game?, heartRate: Double?) {
        guard let game, session.activationState == .activated, session.isReachable else { return }
        var info: [String: Any] = [
            SyncKey.liveOpponent: game.opponent,
            SyncKey.liveStartDate: game.startDate.timeIntervalSince1970,
            SyncKey.liveIsOnIce: game.isOnIce,
            SyncKey.liveShiftCount: game.shifts.count
        ]
        if let heartRate { info[SyncKey.liveHeartRate] = heartRate }
        session.sendMessage(info, replyHandler: nil, errorHandler: { _ in })
    }

    func notifyGameEnded() {
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SyncKey.liveEnded: true], replyHandler: nil, errorHandler: { _ in })
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
