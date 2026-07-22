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

## Setup notes (done on the Mac, not in this container)

- Create the watchOS target in Xcode (SwiftUI, watchOS 10+).
- Capabilities: HealthKit (workout session + heart rate), background delivery.
- Keep capture responsive: buffer events locally, sync opportunistically.

## Rules for this component

- UI-fast, low-friction interactions — you're tapping with gloves near the boards.
- Never block the capture flow on network; queue and sync later.
- Shared model types stay byte-compatible with the contract JSON.
