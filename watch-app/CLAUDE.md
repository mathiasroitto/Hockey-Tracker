# watch-app/ — watchOS capture app

Owned by `watch-agent`. Runs on Apple Watch during a game to capture data.

## Responsibility

- On-wrist UX for live capture: start/stop the game, log events (goal, assist,
  shot, hit, block, penalty, faceoff, takeaway, giveaway), track shifts.
- Read HealthKit during the game (heart rate, active energy) and roll it up into
  a `BiometricSummary`.
- Build a `GameIngest` payload and sync it to the phone (and/or the server).

## Contract

Model types mirror the schemas in `contract/openapi.yaml`:
`GameIngest`, `GameEvent`, `EventType`, `Shift`, `BiometricSummary`.
Define them as Swift `Codable` structs. Do not add fields that aren't in the
contract — request a contract change instead.

If/when this app calls `PATCH /me` to set the display name (see below), also
mirror `UserUpdate` (`{ displayName?: string | null }`) as a `Codable` struct.
Only add it when the watch actually performs the capture; otherwise the phone
owns it and the watch doesn't need the type.

## Authentication (Sign in with Apple)

Every server call except `/health` needs a Sign in with Apple identity token in
the `Authorization: Bearer <token>` header (see the `appleIdentityToken` scheme
in the contract). The server derives the user from the token, so no user id is
sent in payloads — data is scoped server-side.

- Use `AuthenticationServices` (`ASAuthorizationAppleIDProvider`) to sign in and
  obtain the `identityToken`.
- Attach it to every request. Handle 401 by re-authenticating.
- watchOS is often paired-phone-driven for sign-in; obtaining/refreshing the
  token may need to happen on the phone and sync to the watch. Confirm the flow
  before building capture-time networking.

### Populating the display name

Apple returns the user's name (`ASAuthorizationAppleIDCredential.fullName`, a
`PersonNameComponents`) to the client **only on the very first authorization**
for this app's Apple ID. It is **not** carried in the identity token, and Apple
will not send it again on subsequent sign-ins. So the display name can only be
captured by whichever client runs that first authorization — it must read
`fullName`, format it (e.g. `PersonNameComponentsFormatter`), and persist it
server-side via `PATCH /me` with body `{ "displayName": "..." }` (the
`UserUpdate` schema). The server has no other way to learn the name.

- **Coordination point:** on watchOS the initial Sign in with Apple flow is
  usually driven from the paired iPhone. If the iOS app owns that first
  authorization, it captures `fullName` and calls `PATCH /me`; the watch then
  just consumes the resulting identity (token) and does **not** need to touch
  the name. Do not assume the watch does the capture — confirm which side runs
  the first authorization.
- If the watch **does** perform its own first authorization (no phone in the
  loop), then the watch is responsible for the capture: read `fullName`, format
  it, and send `PATCH /me` itself, mirroring `UserUpdate` as a `Codable` struct.
- Missing/empty `fullName` on a later sign-in is expected — never overwrite an
  existing display name with an empty value.

## Project structure

Sources live under `Sources/`, grouped by concern. The Xcode project is
generated with XcodeGen from the **root** `project.yml`, which composes this app
(embedded in the iOS app) and the iOS app into one paired project — see
`../CLAUDE.md` → Building the apps. This app's target spec is the fragment
`watch-app/targets.yml` (owned by watch-agent); never hand-edit the `.xcodeproj`:

```
watch-app/
  targets.yml                 # XcodeGen target fragment (composed by root project.yml)
  Sources/
    App/
      HockeyTrackerWatchApp.swift  # @main; wires GameSession/HealthKit/Sync
      RootView.swift               # flow: preGame -> capturing -> ended
    # Contract models (EventType, GameEvent, Shift, BiometricSummary,
    # GameIngest, …) + ContractJSON/ContractDate come from the shared
    # HockeyContract package (../shared/) — import HockeyContract. This app no
    # longer defines its own copies. Build the capture grid from
    # EventType.loggable (excludes the .unknown forward-compat case).
    Capture/
      GameSession.swift        # ObservableObject: periods, events, shifts, ingest
    Health/
      HealthKitManager.swift   # HKWorkoutSession -> BiometricSummary + HR zones
    Networking/
      TokenProvider.swift      # auth seam (bearer token from the phone)
      APIClient.swift          # async POST /games/ingest
      GameSyncManager.swift    # disk buffer + opportunistic retry
    Views/
      PreGameView.swift        # opponent/location/periods -> start
      CaptureView.swift        # glove-friendly event grid + shift toggle
      EndGameView.swift        # summary + sync trigger
      EventType+Display.swift  # UI labels/tints for EventType (not in model)
    Generated/                 # Info.plist + entitlements emitted by XcodeGen
```

### Contract mirror notes

The contract models live in the shared `HockeyContract` package; these notes
describe how this app uses them.

- `GameIngest.date` is a `Date` (calendar day); the package codes it as
  `yyyy-MM-dd`, not a full timestamp. `Date` instant fields (`timestamp`,
  `startTime`) serialize as ISO-8601 UTC via `ContractJSON`. Build a `GameIngest`
  by passing the game's `Date` directly.
- `EventType` raw values are the exact contract strings (`faceoff_win`,
  `faceoff_loss`, etc.); it includes a `.unknown` forward-compat case, so build
  the capture grid from `EventType.loggable` (which excludes it).
- `BiometricSummary.timeInZonesSeconds` is a `[String: Double]?` map of zone
  label -> seconds. Zone buckets are fixed BPM ranges documented in
  `HealthKitManager` (zone1 <120 ... zone5 >=180).

### Auth seam (token hand-off from the phone)

`TokenProvider` is the seam for the bearer token. The paired **iPhone owns Sign
in with Apple**; the watch never runs the sign-in flow. The phone pushes its
current auth state to the watch over WatchConnectivity, and
`WatchConnectivityTokenProvider` (in `Sources/Networking/`) caches it and feeds
it to `APIClient`. `PlaceholderTokenProvider` is retained for dev/tests only —
the app wiring (`HockeyTrackerWatchApp.init`) uses the real provider.

**Transport:** `WCSession.updateApplicationContext(_:)`. The application context
always holds the single latest auth state and is delivered when the watch next
becomes reachable or launches — the right fit for "the current token" (not a
message queue).

**Shared application-context keys (MUST match the iOS app exactly):**

| Key             | Type   | Meaning                                                        |
| --------------- | ------ | ------------------------------------------------------------- |
| `signedIn`      | `Bool` | Whether the phone currently has an authenticated user.        |
| `identityToken` | `String` | Current Sign in with Apple identity token when `signedIn`; `""` when signed out. |

**Semantics (watch side):** apply the latest context both at activation (read
`session.receivedApplicationContext` after `activate()`) **and** live
(`session(_:didReceiveApplicationContext:)`). When `signedIn` is true and the
token is non-empty, store it; when false or empty, clear it. The token is stored
thread-safely (an `NSLock`); `currentToken()` returns the latest cached value
and never blocks.

**Companion-pairing prerequisite:** WatchConnectivity requires the watch app to
be a companion of the iOS app. This is now satisfied structurally: the root
`project.yml` embeds this watch target inside the iOS app, and
`WKCompanionAppBundleIdentifier` is set to `com.hockeytracker.ios` in the
generated Info.plist (via `watch-app/targets.yml`).

**Capture/sync unaffected before a token arrives:** with no token,
`currentToken()` returns `nil`, `APIClient` throws `.missingToken`, and
`GameSyncManager` keeps the game buffered on disk for the next retry. Capture is
never blocked on the network or on auth.

## Setup notes (done on the Mac, not in this container)

- `brew install xcodegen` then `xcodegen generate` from the **repo root** (one
  project holds both apps); open the `HockeyTracker` scheme to build the iOS app
  with this watch app embedded, or the `HockeyTrackerWatch` scheme to run the
  watch app directly.
- Capabilities are declared in `watch-app/targets.yml`: HealthKit entitlement +
  the `workout-processing` background mode + Health usage descriptions.
- Bundle id is `com.hockeytracker.watch` (pairs with `com.hockeytracker.ios`).
- `APIClient` base URL defaults to `http://localhost:8000` (contract dev server).
- Keep capture responsive: events buffer locally; sync is opportunistic and
  never blocks the capture flow.

## Rules for this component

- UI-fast, low-friction interactions — you're tapping with gloves near the boards.
- Never block the capture flow on network; queue and sync later.
- Shared model types stay byte-compatible with the contract JSON.
