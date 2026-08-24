# Handoff / continuation guide

Read this first if you're picking up Hockey-Tracker fresh — a new machine, a new
Claude account, or a new session with no memory of how it got here. It captures
the *why* behind the code, the traps already hit, and what to do next. For the
*how-to-run*, see `DEVELOPMENT.md`; for conventions and the agent workflow, see
`CLAUDE.md`.

## Orientation (read order)

1. `README.md` — what the project is.
2. `CLAUDE.md` — conventions + the "one agent per bounded context" way of working
   (auto-loaded by Claude Code as project memory).
3. `DEVELOPMENT.md` — clone-and-run setup for every component.
4. This file — status, decisions, gotchas, next steps.
5. `contract/openapi.yaml` (+ `contract/CHANGELOG.md`) — the source of truth.

The **git history is part of the memory**: commit messages explain each change.
`main` is the source of truth and has everything.

## Moving to another Claude account

The repository *is* the portable memory — nothing needed lives only in an
account:

- `CLAUDE.md` files (root + per-component) load automatically in any Claude Code
  session. `.claude/agents/*` (the subagents) and `.claude/settings.json` (the
  SessionStart hook) travel with the repo and work for any account.
- **No secrets are in the repo.** The only configured value, `APPLE_CLIENT_ID`,
  is a public bundle id (`com.hockeytracker.ios`).
- In the new account: make sure it has **GitHub access to
  `mathiasroitto/hockey-tracker`**, then clone/pull `main`. In Claude Code on the
  web, the SessionStart hook auto-provisions the Python server env on first run.
- Claude "memory" itself is **not** account-portable — that's exactly why the
  context is written into these files instead.

## Status (as of the latest commit on `main`)

| Component | State |
| --------- | ----- |
| `contract/` | v0.4.0. Games ingest/list (+opponent/date filters), per-game & career stats, Sign in with Apple auth, per-user scoping, `GET/PATCH /me`. |
| `server/` | Complete against v0.4.0. FastAPI + SQLModel/SQLite + Alembic. **20 tests passing.** Runs & tested in this environment. |
| `shared/` | `HockeyContract` Swift package — the single Swift mirror of the contract, imported by both apps. Has `swift test` tests. |
| `ios-app/` | MVP: SIWA, API client, games list + detail + career stats, displayName, pushes token to watch. |
| `watch-app/` | MVP: live event/shift capture, HealthKit, GameIngest sync w/ offline buffer, receives token from phone. |
| Build | iOS + watch build as **one paired Xcode project** from the root `project.yml` (watch embedded in iOS). |

**Important validation caveat:** this cloud environment has **no Swift/Xcode
toolchain**, so all Swift (the package, both apps, and the XcodeGen specs) was
verified by static inspection and cross-checks — **not compiled**. The Python
server is fully run and tested. First thing to do in a real dev env: compile the
Swift (see Next steps).

## Key decisions & rationale (so you don't relitigate them)

- **Monorepo, contract-first, one agent per bounded context.** Only
  `contract-agent` changes `contract/openapi.yaml`; server + shared package +
  apps consume it. This is what keeps parallel work from drifting.
- **Server storage** sits behind a `GameStore` interface; SQLite today, swap to
  Postgres via `HOCKEY_DB_URL` with no route changes. Alembic owns the schema.
- **Auth = Sign in with Apple.** The server verifies the identity JWT and scopes
  all data per user. `displayName` is set via `PATCH /me` because **Apple only
  returns the user's name to the client on the first authorization and never in
  the token** — so the client must capture and send it. Don't try to read it
  server-side; it isn't there.
- **Timestamps:** the server emits canonical millisecond ISO-8601 UTC (`…Z`);
  clients parse *any* fractional precision. (See the gotcha below for why.)
- **Paired Apple project:** a watch app + its companion iOS app must build as one
  project for WatchConnectivity to work, so the root `project.yml` embeds the
  watch in the iOS app. Generate from the **repo root**, not the app subdirs.
- **Phone→watch token hand-off** uses `WCSession.updateApplicationContext` with
  keys `signedIn` (Bool) + `identityToken` (String). Both apps share those exact
  keys — it's an on-device contract OpenAPI can't express.
- **Shared package reconciliations:** `EventType` has a `.unknown` forward-compat
  case plus `.loggable` (producers use that, excludes `.unknown`); `GameIngest.date`
  is a `Date` coded as `yyyy-MM-dd` while instant fields stay ISO-8601.

## Gotchas already hit (don't rediscover these the hard way)

- **No Swift toolchain here** → validate Swift on a Mac: `swift test` in
  `shared/`, and `xcodegen generate` **from the repo root** then build. Expect to
  smooth over a path/embedding detail on the very first generate.
- **SQLite + Alembic batch mode needs *named* constraints.** Autogenerate emits
  `create_foreign_key(None, …)` which fails with "Constraint must have a name" —
  name FKs explicitly in the migration. (See `server/CLAUDE.md`.)
- **FastAPI/Pydantic serializes datetimes as 6-digit microseconds** by default,
  but Apple's `ISO8601DateFormatter(.withFractionalSeconds)` accepts *exactly 3*.
  Fixed by pinning the server to millisecond output + lenient client parsing.
  Keep both sides that way.
- **`APPLE_CLIENT_ID` must equal the iOS bundle id** (`com.hockeytracker.ios`);
  the server returns 500 if it's unset (deliberate — never skip audience checks).
- **Adding a NOT NULL FK column** (the `user_id` migration) assumes an empty
  table — fine pre-release, but backfill before doing that on real data.
- **This sandbox blocks git ref *deletion*** (normal pushes work). The old
  feature branch couldn't be deleted from here; do it from the GitHub UI if you
  want. Everything is on `main` regardless.

## Next steps (roughly prioritized)

1. **Compile the Swift on a Mac** — `swift test` in `shared/`; `xcodegen generate`
   from the repo root; build the `HockeyTracker` and `HockeyTrackerWatch` schemes;
   fix any first-generate issues. This is the biggest unvalidated surface.
2. **Add `Assets.xcassets` + `AppIcon`** to each app (needed before archiving).
3. **iOS token storage → Keychain** (the MVP uses UserDefaults — see `TokenStore`).
4. **Live end-to-end auth test** with a real Apple identity token on a device/
   simulator (server auth is unit-tested with the dependency overridden).
5. **Product features**: surface `displayName` in a profile header, pagination on
   `GET /games`, richer stats/charts, etc.

When you add a feature, follow the workflow: shape it in `contract/` first
(`contract-agent`), then implement in `server/`, `shared/`, and the apps.
