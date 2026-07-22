# Contract changelog

All notable changes to `openapi.yaml`. Format loosely follows Keep a Changelog;
versions follow SemVer against `info.version`.

## [0.1.0] — 2026-07-22

### Added

- Initial contract.
- Core schemas: `EventType`, `GameEvent`, `Shift`, `BiometricSummary`,
  `GameIngest`, `Game`, `GameStats`, `CareerStats`.
- Endpoints: `GET /health`, `GET /games`, `POST /games/ingest`,
  `GET /games/{gameId}`, `GET /games/{gameId}/stats`, `GET /stats/career`.
