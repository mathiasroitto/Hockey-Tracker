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
response schemas: `User`, `Game`, `GameStats`, `CareerStats`, and the shared
shapes (`GameEvent`, `Shift`, `BiometricSummary`). Define them as Swift
`Codable` structs kept in sync with the contract.

## Authentication (Sign in with Apple)

Every server call except `/health` needs a Sign in with Apple identity token in
the `Authorization: Bearer <token>` header (`appleIdentityToken` scheme). Data
is scoped to the authenticated user server-side — the app only ever sees its
own games.

- Use `AuthenticationServices` / `SignInWithAppleButton` (SwiftUI) to sign in
  and obtain the `identityToken`; attach it to every request.
- Call `GET /me` after sign-in to confirm the token and get the user's id.
- Handle 401 by prompting re-authentication.

## Setup notes (done on the Mac, not in this container)

- Create a universal iOS/iPadOS target in Xcode (SwiftUI, iOS 17+).
- Use Swift Charts for trends and shift/biometric visualizations.
- Adapt layouts for both iPhone (compact) and iPad (regular) size classes.

## Rules for this component

- Read-heavy: this app displays; the server computes. Don't reimplement stats
  math the server already owns — call `/games/{id}/stats` and `/stats/career`.
- Shared model types stay byte-compatible with the contract JSON.
