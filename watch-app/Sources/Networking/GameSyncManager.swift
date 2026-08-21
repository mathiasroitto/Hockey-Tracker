import Foundation
import Combine
import HockeyContract

/// Buffers finished games on disk and syncs them opportunistically.
///
/// Capture never blocks on the network: `enqueue(_:)` persists the game
/// immediately and returns, then a background sync attempt runs. Anything that
/// fails to upload stays on disk and is retried on the next `syncPending()`
/// (e.g. app foreground, or a manual retry from the end-of-game screen).
@MainActor
final class GameSyncManager: ObservableObject {

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced
        case failed(String)
    }

    @Published private(set) var pendingCount = 0
    @Published private(set) var state: SyncState = .idle

    private let client: APIClient
    private let directory: URL

    init(client: APIClient, directory: URL? = nil) {
        self.client = client
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("PendingGames", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        refreshPendingCount()
    }

    /// Persist a finished game and kick off a (non-blocking) sync attempt.
    func enqueue(_ game: GameIngest) {
        persist(game)
        refreshPendingCount()
        Task { await syncPending() }
    }

    /// Attempt to upload every buffered game. Uploaded games are deleted; failed
    /// ones remain for the next attempt.
    func syncPending() async {
        let files = pendingFiles()
        guard !files.isEmpty else {
            state = .idle
            return
        }
        state = .syncing

        var lastError: String?
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let game = try? ContractJSON.decoder.decode(GameIngest.self, from: data) else {
                // Corrupt file: drop it so it can't wedge the queue forever.
                try? FileManager.default.removeItem(at: file)
                continue
            }
            do {
                try await client.ingest(game)
                try? FileManager.default.removeItem(at: file)
            } catch {
                lastError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }

        refreshPendingCount()
        state = pendingCount == 0 ? .synced : .failed(lastError ?? "Sync incomplete")
    }

    // MARK: Disk buffer

    private func persist(_ game: GameIngest) {
        let url = directory.appendingPathComponent("\(UUID().uuidString).json")
        if let data = try? ContractJSON.encoder.encode(game) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func pendingFiles() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents.filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
    }

    private func refreshPendingCount() {
        pendingCount = pendingFiles().count
    }
}
