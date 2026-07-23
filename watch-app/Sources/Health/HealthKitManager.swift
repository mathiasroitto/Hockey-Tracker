import Foundation
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

/// Runs an HKWorkoutSession for the duration of a game and rolls the collected
/// heart-rate and active-energy data into a `BiometricSummary`.
///
/// Heart-rate zones (documented, intentionally simple — fixed BPM buckets rather
/// than %-of-max, since the Watch app has no reliable max-HR profile at capture
/// time):
///
///   zone1: < 120 bpm    (recovery / bench)
///   zone2: 120–139 bpm  (easy)
///   zone3: 140–159 bpm  (moderate)
///   zone4: 160–179 bpm  (hard)
///   zone5: >= 180 bpm   (max)
///
/// Time-in-zone is accumulated by attributing the gap between two consecutive
/// heart-rate samples to the zone of the earlier sample.
@MainActor
final class HealthKitManager: NSObject, ObservableObject {

    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var latestHeartRate: Double = 0

    /// Heart-rate zone bucket boundaries (upper-exclusive), in bpm.
    static let zoneUpperBounds: [(label: String, upperExclusive: Double)] = [
        ("zone1", 120),
        ("zone2", 140),
        ("zone3", 160),
        ("zone4", 180),
        ("zone5", .greatestFiniteMagnitude)
    ]

    private static func zoneLabel(forBpm bpm: Double) -> String {
        for bucket in zoneUpperBounds where bpm < bucket.upperExclusive {
            return bucket.label
        }
        return zoneUpperBounds.last!.label
    }

#if canImport(HealthKit) && os(watchOS)
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType(.heartRate)
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)

    // Running roll-up state.
    private var heartRateSum: Double = 0
    private var heartRateSampleCount: Int = 0
    private var maxHeartRate: Double = 0
    private var activeEnergyKcal: Double = 0
    private var timeInZones: [String: Double] = [:]
    private var lastHeartRate: Double?
    private var lastHeartRateAt: Date?

    /// Request HealthKit authorization for the types we read and the workout we
    /// write. Safe to call repeatedly.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set = [HKQuantityType.workoutType()]
        let read: Set<HKObjectType> = [heartRateType, activeEnergyType]
        do {
            try await healthStore.requestAuthorization(toShare: share, read: read)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    /// Start the workout session for the game. Resets the roll-up.
    func startWorkout() {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        resetRollup()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hockey
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// Stop the workout session and finish the builder. The summary is captured
    /// from the running roll-up before teardown, so call `makeSummary()` after.
    func stopWorkout() async {
        guard let session, let builder else { return }
        session.end()
        let end = Date()
        try? await builder.endCollection(at: end)
        _ = try? await builder.finishWorkout()
        self.session = nil
        self.builder = nil
        isRunning = false
    }

    /// Build the summary from whatever has been collected so far. Returns `nil`
    /// if no heart-rate samples were seen (e.g. HealthKit denied) so the game
    /// can be uploaded with `biometrics: null`.
    func makeSummary() -> BiometricSummary? {
        guard heartRateSampleCount > 0 else { return nil }
        // Attribute the final open interval to the last sample's zone.
        flushOpenZoneInterval(asOf: Date())
        return BiometricSummary(
            avgHeartRate: heartRateSum / Double(heartRateSampleCount),
            maxHeartRate: maxHeartRate,
            activeEnergyKcal: activeEnergyKcal,
            timeInZonesSeconds: timeInZones.isEmpty ? nil : timeInZones
        )
    }

    private func resetRollup() {
        heartRateSum = 0
        heartRateSampleCount = 0
        maxHeartRate = 0
        activeEnergyKcal = 0
        timeInZones = [:]
        lastHeartRate = nil
        lastHeartRateAt = nil
    }

    private func ingestHeartRate(_ bpm: Double, at time: Date) {
        // Close the interval from the previous sample into its zone.
        flushOpenZoneInterval(asOf: time)

        heartRateSum += bpm
        heartRateSampleCount += 1
        maxHeartRate = max(maxHeartRate, bpm)
        latestHeartRate = bpm
        lastHeartRate = bpm
        lastHeartRateAt = time
    }

    private func flushOpenZoneInterval(asOf now: Date) {
        guard let lastHeartRate, let lastHeartRateAt else { return }
        let elapsed = now.timeIntervalSince(lastHeartRateAt)
        guard elapsed > 0 else { return }
        let label = Self.zoneLabel(forBpm: lastHeartRate)
        timeInZones[label, default: 0] += elapsed
        self.lastHeartRateAt = now
    }
#else
    // Non-watchOS builds (e.g. previews / linting) get inert no-ops.
    func requestAuthorization() async {}
    func startWorkout() {}
    func stopWorkout() async {}
    func makeSummary() -> BiometricSummary? { nil }
#endif
}

#if canImport(HealthKit) && os(watchOS)
extension HealthKitManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in self.isRunning = false }
    }
}

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let hrType = HKQuantityType(.heartRate)
        let energyType = HKQuantityType(.activeEnergyBurned)
        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        for type in collectedTypes {
            guard let stats = workoutBuilder.statistics(for: type) else { continue }
            if type == hrType, let quantity = stats.mostRecentQuantity() {
                let bpm = quantity.doubleValue(for: hrUnit)
                let at = stats.mostRecentQuantityDateInterval()?.end ?? Date()
                Task { @MainActor in self.ingestHeartRate(bpm, at: at) }
            } else if type == energyType, let quantity = stats.sumQuantity() {
                let kcal = quantity.doubleValue(for: .kilocalorie())
                Task { @MainActor in self.activeEnergyKcal = kcal }
            }
        }
    }
}
#endif
