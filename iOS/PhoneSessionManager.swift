import Foundation
import WatchConnectivity

/// A best-effort snapshot of a game currently being played on the watch, used
/// to show a "live" banner in the phone app.
struct LiveStatus: Equatable {
    var opponent: String
    var startDate: Date
    var isOnIce: Bool
    var shiftCount: Int
    var heartRate: Double?
    var lastUpdate: Date
}

/// Phone side of the phone <-> watch bridge.
///
/// Receives finished games (as file transfers) from the watch and saves them to
/// the local `GameStore`, and listens for lightweight live updates while a game
/// is in progress.
final class PhoneSessionManager: NSObject, ObservableObject {
    @Published var liveStatus: LiveStatus?

    private let store: GameStore
    private var session: WCSession { .default }

    init(store: GameStore) {
        self.store = store
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func handleReceivedGame(data: Data) {
        guard let game = try? Game.decodeFromSync(data) else { return }
        DispatchQueue.main.async {
            self.store.save(game)
            // The game just arrived, so it is no longer "live".
            self.liveStatus = nil
        }
    }

    private func handleLive(_ message: [String: Any]) {
        let ended = message[SyncKey.liveEnded] as? Bool == true
        let opponent = message[SyncKey.liveOpponent] as? String
        let startInterval = message[SyncKey.liveStartDate] as? TimeInterval
        let isOnIce = message[SyncKey.liveIsOnIce] as? Bool ?? false
        let shiftCount = message[SyncKey.liveShiftCount] as? Int ?? 0
        let heartRate = message[SyncKey.liveHeartRate] as? Double

        DispatchQueue.main.async {
            if ended {
                self.liveStatus = nil
                return
            }
            guard let opponent, let startInterval else { return }
            self.liveStatus = LiveStatus(
                opponent: opponent,
                startDate: Date(timeIntervalSince1970: startInterval),
                isOnIce: isOnIce,
                shiftCount: shiftCount,
                heartRate: heartRate,
                lastUpdate: Date()
            )
        }
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a newly paired watch can keep syncing.
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[SyncKey.payloadType] as? String == SyncPayloadType.finishedGame.rawValue,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        handleReceivedGame(data: data)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleLive(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleLive(message)
        replyHandler([:])
    }
}
