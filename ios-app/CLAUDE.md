# ios-app/ — iPhone/iPad stats app

Owned by `ios-agent`. Displays statistics per game and over time.

## Responsibility

- Fetch games and stats from the server and present them.
- Per-game view: box score, shift chart, heart-rate/biometric summary.
- Aggregate views: career totals, points-per-game trends, shooting %, ice time.
- Optionally receive `GameIngest` payloads relayed from the Watch and forward
  them to the server.

## Contract

Consumes the server API in `contract/openapi.yaml`. Model types mirror the
response schemas: `User`, `UserUpdate`, `Game`, `GameStats`, `CareerStats`, and
the shared shapes (`GameEvent`, `Shift`, `BiometricSummary`). Define them as
Swift `Codable` structs kept in sync with the contract. `UserUpdate` is the
request body for `PATCH /me` (`{ displayName?: string | null }`).

## Authentication (Sign in with Apple)

Every server call except `/health` needs a Sign in with Apple identity token in
the `Authorization: Bearer <token>` header (`appleIdentityToken` scheme). Data
is scoped to the authenticated user server-side — the app only ever sees its
own games.

- Use `AuthenticationServices` / `SignInWithAppleButton` (SwiftUI) to sign in
  and obtain the `identityToken`; attach it to every request.
- Call `GET /me` after sign-in to confirm the token and get the user's id.
- Handle 401 by prompting re-authentication.

### Setting the display name

Apple returns the user's name in `ASAuthorizationAppleIDCredential.fullName`
**only on the very first authorization** for the app; it is never present in the
identity token. So the name has to be captured at that first sign-in and pushed
to the server — the server cannot derive it from the token.

- On the first successful authorization, read `credential.fullName`
  (`PersonNameComponents`) and format it with `PersonNameComponentsFormatter`
  into a display string.
- Send it to the server via `PATCH /me` with a `UserUpdate` body
  (`{ "displayName": "<formatted name>" }`).
- On later sign-ins `fullName` is `nil`. Do **not** send `displayName: nil` in
  that case — it would overwrite an already-stored name. Only issue the `PATCH`
  when a non-nil, non-empty name is actually available.

## Setup notes (done on the Mac, not in this container)

- Create a universal iOS/iPadOS target in Xcode (SwiftUI, iOS 17+).
- Use Swift Charts for trends and shift/biometric visualizations.
- Adapt layouts for both iPhone (compact) and iPad (regular) size classes.

## Rules for this component

- Read-heavy: this app displays; the server computes. Don't reimplement stats
  math the server already owns — call `/games/{id}/stats` and `/stats/career`.
- Shared model types stay byte-compatible with the contract JSON.
