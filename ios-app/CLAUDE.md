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

## Project layout

The Xcode project is generated from `project.yml` with XcodeGen — the
`.xcodeproj` is not committed. Source lives under `Sources/`:

```
ios-app/
  project.yml                 # XcodeGen spec (iOS 17+, universal, SwiftUI)
  Resources/
    Info.plist
    HockeyTracker.entitlements  # Sign in with Apple capability
  Sources/
    App/          HockeyTrackerApp.swift   # @main, DI of APIClient + AuthSession, AppConfig
    Models/       Codable structs mirroring the contract (see below)
    Networking/   APIClient (async/await URLSession), APIError
    Auth/         AuthSession (Sign in with Apple flow), TokenStore
    Support/      JSONCoding (date strategies), Formatting
    Views/        RootView, SignInView, HomeView, GameDetailView,
                  CareerStatsView, ProfileEditorView, AsyncContentView
```

Models: `User`, `UserUpdate`, `Game`, `GameIngest`, `GameStats`, `CareerStats`,
`GameEvent`, `Shift`, `BiometricSummary`, `EventType`. Optional/nullable and
integer-vs-number types follow `contract/openapi.yaml` exactly. `UserUpdate`
uses a double optional (`String??`) so it can distinguish "omit" (leave
unchanged) from explicit `null` (clear).

Dates: `JSONCoding` decodes both ISO-8601 `date-time` (with/without fractional
seconds) and plain `yyyy-MM-dd` calendar dates; the game `date` is a calendar
day rendered in UTC.

## Generating and running (on the Mac, not in this container)

```bash
cd ios-app
brew install xcodegen         # once
xcodegen generate             # writes HockeyTracker.xcodeproj
open HockeyTracker.xcodeproj
```

- Bundle id: `com.hockeytracker.ios`. This is the Sign in with Apple audience,
  so it must equal the server's `APPLE_CLIENT_ID`.
- Base URL defaults to `http://localhost:8000`; override per-scheme with the
  `HT_BASE_URL` environment variable (see `AppConfig`).
- Set `DEVELOPMENT_TEAM` in `project.yml` and confirm the "Sign in with Apple"
  capability on the target before running on a device.

## Notes

- Use Swift Charts for the shift chart, HR-zone breakdown, and career summary.
- Layouts adapt to iPhone (compact) and iPad (regular): adaptive grids and a
  max content width keep detail/career views readable on iPad.
- Token storage is UserDefaults-backed for the MVP (documented in `TokenStore`);
  move to Keychain for production. Apple identity tokens are short-lived, so a
  401 demotes the session to signed-out and prompts re-auth.

## Rules for this component

- Read-heavy: this app displays; the server computes. Don't reimplement stats
  math the server already owns — call `/games/{id}/stats` and `/stats/career`.
- Shared model types stay byte-compatible with the contract JSON.
