import Foundation
import HealthKit
import CoreLocation
import Combine

/// Coordinates the live recording of a game on the Apple Watch.
///
/// Responsibilities:
///   * Runs an `HKWorkoutSession` so the app keeps executing in the background
///     for the whole game (this is what lets the watch keep tracking while it
///     is on the wrist and the screen is down).
///   * Streams **heart rate**, **distance** and **active energy** from
///     HealthKit's live workout builder.
///   * Streams **speed** from CoreLocation.
///   * Records **shifts** (on-ice toggles) and appends every reading to the
///     `GameStore`'s active game, flushing to disk periodically so a dead
///     battery loses at most a few seconds of data.
///
/// Heart-rate recovery and all other summary numbers are derived later by
/// `GameStatistics`; this class only records the raw stream.
final class WorkoutManager: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case requestingAuthorization
        case active
        case ended
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    // Live values shown on the active-game screen.
    @Published private(set) var currentHeartRate: Double?
    @Published private(set) var currentSpeed: Double?      // meters / second
    @Published private(set) var distance: Double = 0       // meters
    @Published private(set) var activeEnergy: Double = 0   // kcal
    @Published private(set) var isOnIce: Bool = false
    @Published private(set) var shiftCount: Int = 0
    /// Updated by a timer so the UI clocks tick every second.
    @Published private(set) var tick: Date = Date()

    private let store: GameStore
    private let session = WatchSessionManager.shared

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let locationManager = CLLocationManager()

    private var uiTimer: Timer?
    private var lastFlush = Date()
    private var lastLiveUpdate = Date.distantPast

    init(store: GameStore) {
        self.store = store
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    // MARK: - Authorization

    /// Request the HealthKit + location permissions the recording needs.
    func requestAuthorization() async {
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.activitySummaryType()
        ]
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            // Non-fatal: the user can still record shifts/speed without HealthKit.
        }
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Game lifecycle

    func startGame(opponent: String) {
        guard phase != .active else { return }
        _ = store.startGame(opponent: opponent)
        beginWorkout()
        startLocation()
        startTimer()
        phase = .active
        isOnIce = false
        shiftCount = 0
        session.sendLiveUpdate(for: store.activeGame, heartRate: nil)
    }

    /// Resume a game that was recovered from disk after an abnormal exit.
    func resumeRecoveredGame() {
        guard let game = store.activeGame, !game.isFinished else { return }
        beginWorkout()
        startLocation()
        startTimer()
        phase = .active
        isOnIce = game.isOnIce
        shiftCount = game.shifts.count
    }

    /// Toggle the player on/off the ice (start or end a shift).
    func toggleShift() {
        guard phase == .active else { return }
        store.updateActiveGame { game in
            if let idx = game.shifts.lastIndex(where: { $0.endDate == nil }) {
                game.shifts[idx].endDate = Date()
            } else {
                game.shifts.append(Shift(startDate: Date()))
            }
        }
        isOnIce = store.activeGame?.isOnIce ?? false
        shiftCount = store.activeGame?.shifts.count ?? 0
        store.flushActiveGame()
        session.sendLiveUpdate(for: store.activeGame, heartRate: currentHeartRate)
    }

    /// End the game: stop tracking, finalize storage, and ship it to the phone.
    func endGame() {
        store.updateActiveGame(persist: false) { game in
            game.totalDistance = max(game.totalDistance, self.distance)
            game.activeEnergyBurned = max(game.activeEnergyBurned, self.activeEnergy)
        }
        let finished = store.finishActiveGame()
        stopTimer()
        stopLocation()
        endWorkout()
        phase = .ended
        if let finished {
            session.send(finishedGame: finished)
            session.notifyGameEnded()
        }
    }

    func reset() {
        phase = .idle
        currentHeartRate = nil
        currentSpeed = nil
        distance = 0
        activeEnergy = 0
        isOnIce = false
        shiftCount = 0
    }

    // MARK: - HealthKit workout session

    private func beginWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hockey
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            self.workoutSession = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
        } catch {
            // HealthKit unavailable (e.g. Simulator) — keep recording shifts/speed.
            phase = .active
        }
    }

    private func endWorkout() {
        guard let workoutSession, let builder else { return }
        workoutSession.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { _, _ in }
        }
        self.workoutSession = nil
        self.builder = nil
    }

    // MARK: - Location / speed

    private func startLocation() {
        locationManager.startUpdatingLocation()
    }

    private func stopLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Timer (UI clocks + periodic disk flush + live updates)

    private func startTimer() {
        uiTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.onTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer
    }

    private func stopTimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    private func onTick() {
        tick = Date()
        let now = Date()
        if now.timeIntervalSince(lastFlush) >= 10 {
            // Fold the running distance/energy totals into the stored game so a
            // dead battery doesn't lose them, then flush everything to disk.
            store.updateActiveGame(persist: false) { game in
                game.totalDistance = max(game.totalDistance, self.distance)
                game.activeEnergyBurned = max(game.activeEnergyBurned, self.activeEnergy)
            }
            store.flushActiveGame()
            lastFlush = now
        }
        if now.timeIntervalSince(lastLiveUpdate) >= 5 {
            session.sendLiveUpdate(for: store.activeGame, heartRate: currentHeartRate)
            lastLiveUpdate = now
        }
    }

    // MARK: - Helpers

    /// Run a block on the main thread (where all `@Published` / `GameStore`
    /// mutation must happen). HealthKit and CoreLocation deliver their callbacks
    /// on arbitrary threads, so every state update is funneled through here.
    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        onMain { [weak self] in
            self?.phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            handle(statistics: statistics, of: quantityType)
        }
    }

    private func handle(statistics: HKStatistics, of quantityType: HKQuantityType) {
        switch quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            guard let bpm = statistics.mostRecentQuantity()?.doubleValue(for: unit) else { return }
            onMain { [weak self] in
                guard let self else { return }
                self.currentHeartRate = bpm
                self.store.updateActiveGame(persist: false) { game in
                    game.heartRateSamples.append(HeartRateSample(date: Date(), bpm: bpm))
                }
            }

        case HKQuantityType(.activeEnergyBurned):
            let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            onMain { [weak self] in self?.activeEnergy = kcal }

        case HKQuantityType(.distanceWalkingRunning):
            let meters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            onMain { [weak self] in self?.distance = meters }

        default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.speed >= 0 else { return }
        let speed = location.speed
        onMain { [weak self] in
            guard let self else { return }
            self.currentSpeed = speed
            self.store.updateActiveGame(persist: false) { game in
                game.speedSamples.append(SpeedSample(date: Date(), speed: speed))
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
