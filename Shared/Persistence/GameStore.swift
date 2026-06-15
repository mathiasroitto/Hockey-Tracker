import Foundation
import Combine

/// On-device storage for games, used on both the watch and the phone.
///
/// Design goals:
///   * **Crash / dead-battery safety.** The in-progress game is written to disk
///     after *every* meaningful event (shift start/stop, each heart-rate or
///     speed sample batch). If the watch dies mid-game, the recording is
///     reloaded on next launch instead of being lost.
///   * **Simplicity.** Games are stored as individual JSON files. No database,
///     no schema migrations — a `Game` is just `Codable`.
///
/// `GameStore` is an `ObservableObject` so SwiftUI views can observe `games`
/// and `activeGame` directly. All mutation is expected to happen on the main
/// thread (the workout manager marshals its background callbacks accordingly);
/// disk writes are dispatched off the main thread.
final class GameStore: ObservableObject {
    /// All finished games, most recent first.
    @Published private(set) var games: [Game] = []
    /// The game currently being recorded (watch only), if any.
    @Published private(set) var activeGame: Game?

    private let directory: URL
    private let finishedDirectory: URL
    private let activeGameURL: URL

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directoryName: String = "HockeyTracker") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent(directoryName, isDirectory: true)
        finishedDirectory = directory.appendingPathComponent("finished", isDirectory: true)
        activeGameURL = directory.appendingPathComponent("active.json")

        createDirectoriesIfNeeded()
        loadFinishedGames()
        recoverActiveGame()
    }

    // MARK: - Active game lifecycle (watch)

    /// Begin recording a new game and persist it immediately.
    func startGame(opponent: String) -> Game {
        let game = Game(opponent: opponent, startDate: Date())
        activeGame = game
        persistActiveGame()
        return game
    }

    /// Apply a mutation to the active game.
    ///
    /// - Parameter persist: when `true` (the default) the change is written to
    ///   disk immediately. High-frequency updates (heart-rate / speed samples)
    ///   pass `false` and rely on a periodic `flushActiveGame()` so we are not
    ///   rewriting the file every second.
    func updateActiveGame(persist: Bool = true, _ mutate: (inout Game) -> Void) {
        guard var game = activeGame else { return }
        mutate(&game)
        activeGame = game
        if persist { persistActiveGame() }
    }

    /// Force the in-progress game to disk (called on a timer and on shift
    /// changes so a dead battery loses at most a few seconds of samples).
    func flushActiveGame() {
        persistActiveGame()
    }

    /// Finish the active game, move it into the finished list and persist.
    /// Returns the finished game (handy for kicking off a sync to the phone).
    @discardableResult
    func finishActiveGame() -> Game? {
        guard var game = activeGame else { return nil }
        // Close any shift that is still open.
        if let idx = game.shifts.lastIndex(where: { $0.endDate == nil }) {
            game.shifts[idx].endDate = Date()
        }
        game.endDate = Date()
        activeGame = nil
        removeActiveGameFile()
        save(game)
        return game
    }

    /// Throw away the active recording without saving it.
    func discardActiveGame() {
        activeGame = nil
        removeActiveGameFile()
    }

    // MARK: - Finished games (both platforms)

    /// Insert or replace a finished game (used by the phone when it receives a
    /// game from the watch, and by the watch when it finishes one).
    func save(_ game: Game) {
        if let idx = games.firstIndex(where: { $0.id == game.id }) {
            games[idx] = game
        } else {
            games.append(game)
        }
        games.sort { $0.startDate > $1.startDate }
        writeFinished(game)
    }

    func delete(_ game: Game) {
        games.removeAll { $0.id == game.id }
        let url = finishedDirectory.appendingPathComponent("\(game.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    func statistics(for game: Game) -> GameStatistics { GameStatistics(game: game) }

    // MARK: - Disk I/O

    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: finishedDirectory, withIntermediateDirectories: true)
    }

    private func loadFinishedGames() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: finishedDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let loaded = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Game? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? Self.decoder.decode(Game.self, from: data)
            }
        games = loaded.sorted { $0.startDate > $1.startDate }
    }

    /// On launch, if an active-game file exists the previous session ended
    /// abnormally (battery died, app killed). Reload it so the player can
    /// resume or save it.
    private func recoverActiveGame() {
        guard let data = try? Data(contentsOf: activeGameURL),
              let game = try? Self.decoder.decode(Game.self, from: data) else { return }
        activeGame = game
    }

    private func persistActiveGame() {
        guard let game = activeGame else { return }
        write(game, to: activeGameURL)
    }

    private func removeActiveGameFile() {
        try? FileManager.default.removeItem(at: activeGameURL)
    }

    private func writeFinished(_ game: Game) {
        let url = finishedDirectory.appendingPathComponent("\(game.id.uuidString).json")
        write(game, to: url)
    }

    private func write(_ game: Game, to url: URL) {
        guard let data = try? Self.encoder.encode(game) else { return }
        // Write atomically off the main thread so recording stays responsive.
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: url, options: .atomic)
        }
    }
}
