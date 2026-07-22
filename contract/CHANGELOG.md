# Contract changelog

All notable changes to `openapi.yaml`. Format loosely follows Keep a Changelog;
versions follow SemVer against `info.version`.

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
