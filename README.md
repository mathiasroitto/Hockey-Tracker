# Hockey-Tracker

An Apple Watch + iPhone app to track your hockey games. Start a game on your
**Apple Watch**, wear it while you play, and it records your **heart rate**,
**skating speed**, **heart-rate recovery**, and your **shifts** (count and
length). Everything is stored on the watch as you play — so even if the battery
dies you keep your data — and is synced to your **iPhone** afterwards where you
can dig into the stats.

> The watch is the recorder; the phone is the analyzer.

---

## Features

### On the Apple Watch (recording)
- **Start / end a game** with an optional opponent name.
- **Shifts**: one big button to tap when you hop on the ice and again when you
  come off. Tracks shift **count** and **length**, with a live shift timer.
- **Heart rate**, **distance** and **active energy** via a HealthKit workout
  session (this also keeps the app running for the whole game).
- **Skating speed** via CoreLocation.
- **Runs in the background** for the whole game using an `HKWorkoutSession`.
- **Crash / dead-battery safe**: the in-progress game is written to disk after
  every shift and every few seconds of samples. If the watch dies mid-game, the
  app offers to **resume or save** the recording on next launch.
- **Auto-sync**: when a game ends it is queued for transfer to the iPhone (and
  delivered reliably even if the phone was unreachable at the time).

### On the iPhone (analysis)
- **Live banner** when a game is in progress on the watch.
- **List of games** that have synced over.
- **Per-game detail** with summary tiles, a **heart-rate graph** (with on-ice
  periods shaded), and a **per-shift breakdown** (duration, average HR,
  recovery drop, top speed).

### Metrics explained
- **Shift length / count** — measured from the on-ice button taps.
- **Heart-rate recovery** — for each shift, how many bpm your heart rate drops
  in the ~60 seconds of rest after you come off the ice. A bigger drop generally
  means better conditioning.
- **Speed** — instantaneous speed from GPS (best on outdoor rinks; indoor rinks
  may have limited GPS).

---

## Project layout

```
Shared/                     Code shared by both the watch and phone targets
  Models/                   Game, Shift, samples, and the GameStatistics analyzer
  Persistence/GameStore.swift   On-device JSON storage (battery/crash safe)
  Sync/SyncPayload.swift    WatchConnectivity keys + (de)coding helpers
  Utilities/Formatters.swift

Watch/                      watchOS app (the recorder)
  HockeyTrackerWatchApp.swift
  WorkoutManager.swift      HealthKit workout + CoreLocation + shift logic
  WatchSessionManager.swift WatchConnectivity (sending)
  Views/                    SwiftUI screens

iOS/                        iPhone app (the analyzer)
  HockeyTrackerApp.swift
  PhoneSessionManager.swift WatchConnectivity (receiving)
  Views/                    SwiftUI screens (list, detail, charts)

project.yml                 XcodeGen project definition (source of truth)
Makefile                    Convenience commands
```

### Architecture notes
- **`Game` is the lossless recording** — it stores only raw data (shifts plus
  time-stamped heart-rate and speed samples). Every derived number (average
  shift length, recovery, top speed, …) is computed on demand by
  `GameStatistics`, so the stored format never needs migrating.
- **Persistence is plain JSON files** managed by `GameStore`. The active game is
  flushed to disk frequently for battery-loss safety; finished games are stored
  one file per game.
- **Sync uses WatchConnectivity.** Finished games are sent watch → phone as a
  queued `transferFile` (reliable even when the phone is away). Best-effort
  `sendMessage` updates drive the phone's "game in progress" banner.

---

## Requirements

- macOS with **Xcode 16 or newer**
- An **Apple Developer account** (free is fine for on-device testing) to set a
  signing team
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project:
  `brew install xcodegen`

> **Note on watch embedding (Xcode 16+).** Xcode 16+ requires the watch app to be
> embedded in the host app's `PlugIns/` directory. XcodeGen currently emits the
> older `Watch/` location, so `Scripts/fix-watch-embed.sh` is run automatically
> after generation (via `postGenCommand`) to correct it. It is idempotent and a
> no-op once XcodeGen ships the fix.

The targets deploy to **iOS 17** and **watchOS 10**.

> Heart rate and skating speed require a **physical Apple Watch** — the watchOS
> Simulator does not produce real HealthKit or GPS data. Shifts, persistence and
> sync can be exercised in the simulators.

---

## Getting started

```bash
# 1. Generate the Xcode project from project.yml
make project          # or: xcodegen generate

# 2. Open it
make open             # or: open HockeyTracker.xcodeproj
```

Then in Xcode:

1. Select the **HockeyTracker** (iOS) and **HockeyTrackerWatch** targets and set
   your **Team** under *Signing & Capabilities* (the watch target also needs the
   **HealthKit** capability, which is already declared in its entitlements).
2. Run the **HockeyTrackerWatch** scheme on your paired Apple Watch to record a
   game, then run the **HockeyTracker** scheme on your iPhone to see it sync.

The generated `HockeyTracker.xcodeproj` is intentionally **not committed** (it is
in `.gitignore`); regenerate it with `make project` whenever you add or remove
source files.

### Build from the command line

```bash
make build-ios        # build the iPhone app for the simulator
make build-watch      # build the watch app for the simulator
```

---

## Roadmap ideas

- Auto-detect shifts from motion instead of (or alongside) manual taps.
- Per-period tracking and a face-off/score log.
- Trends across games (recovery and top speed over a season).
- Export to HealthKit workouts on the phone and share sheets.
