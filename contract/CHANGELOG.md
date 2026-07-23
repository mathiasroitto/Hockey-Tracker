# Contract changelog

All notable changes to `openapi.yaml`. Format loosely follows Keep a Changelog;
versions follow SemVer against `info.version`.

## [0.4.0] — 2026-07-23

### Added

- `PATCH /me` (`updateCurrentUser`) — lets the client set the authenticated
  user's `displayName`. Sign in with Apple omits the name from the identity
  token and only returns the full name to the client on the very first
  authorization, so the server cannot derive it. The client captures the name
  once at first sign-in and submits it here.
- `UserUpdate` schema — request body for `PATCH /me`; an optional, nullable
  `displayName`. Omitted fields are left unchanged; an explicit null clears the
  field.

Backward compatible: purely additive (new operation and schema); existing
endpoints are unchanged.

## [0.3.0] — 2026-07-22

### Added

- Sign in with Apple authentication (`appleIdentityToken` bearer scheme),
  applied to every endpoint except `/health`.
- `User` schema and `GET /me` (returns the current user, creating it on first
  sign-in).
- `401 Unauthorized` responses on all protected endpoints.

### Changed (BREAKING)

- All game and stats endpoints now require an `Authorization: Bearer <token>`
  header and are scoped to the authenticated user — a user only sees their own
  games. Unauthenticated requests that previously succeeded now return 401.
- `GET /games/{gameId}` and its stats return 404 when the game belongs to
  another user (no cross-user access).

## [0.2.0] — 2026-07-22

### Added

- `GET /games` now accepts optional query filters, combined with AND:
  - `opponent` — case-insensitive exact match on opponent name.
  - `from` / `to` — inclusive date range on the game date.
- `GET /games` is now documented as ordered by game date (newest first).

Backward compatible: all filters are optional; calling `GET /games` with no
parameters behaves as before.

## [0.1.0] — 2026-07-22

### Added

- Initial contract.
- Core schemas: `EventType`, `GameEvent`, `Shift`, `BiometricSummary`,
  `GameIngest`, `Game`, `GameStats`, `CareerStats`.
- Endpoints: `GET /health`, `GET /games`, `POST /games/ingest`,
  `GET /games/{gameId}`, `GET /games/{gameId}/stats`, `GET /stats/career`.
