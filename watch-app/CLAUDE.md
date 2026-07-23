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

## Setup notes (done on the Mac, not in this container)

- Create the watchOS target in Xcode (SwiftUI, watchOS 10+).
- Capabilities: HealthKit (workout session + heart rate), background delivery.
- Keep capture responsive: buffer events locally, sync opportunistically.

## Rules for this component

- UI-fast, low-friction interactions — you're tapping with gloves near the boards.
- Never block the capture flow on network; queue and sync later.
- Shared model types stay byte-compatible with the contract JSON.
