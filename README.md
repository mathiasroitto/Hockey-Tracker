# Hockey-Tracker

Personal hockey performance tracking: an Apple Watch app to capture data during
games, an iPhone/iPad app to view statistics, and a server that stores and
processes it all.

## Architecture

```
Watch (capture) ──▶ iPhone/iPad ──▶ Server (store + process)
                         ▲                     │
                         └──── stats ──────────┘
```

| Component   | Runtime            | Role                                          |
| ----------- | ------------------ | --------------------------------------------- |
| `watch-app/`| watchOS (SwiftUI)  | Live capture: events, shifts, HealthKit       |
| `ios-app/`  | iOS/iPadOS SwiftUI | Statistics per game and over time             |
| `server/`   | Python / FastAPI   | Ingest, storage, processing/aggregation       |
| `contract/` | OpenAPI            | **Source of truth** for data shapes & the API |

## Way of working: one agent per bounded context

Each component is owned by a dedicated Claude Code subagent in `.claude/agents/`.
The contract is the seam that keeps them consistent — only `contract-agent`
changes data shapes; everyone else implements against them. See `CLAUDE.md` for
the full rules.

| Agent            | Owns        |
| ---------------- | ----------- |
| `contract-agent` | `contract/` |
| `watch-agent`    | `watch-app/`|
| `ios-agent`      | `ios-app/`  |
| `server-agent`   | `server/`   |
| `qa-agent`       | cross-cutting consistency & tests |

## Getting started

New machine? See **[DEVELOPMENT.md](DEVELOPMENT.md)** for the full clone-and-continue
guide (prerequisites, per-component setup, config reference, and current state).

### Server quickstart

```bash
cd server
pip install -e ".[dev]"
export APPLE_CLIENT_ID=<your app's bundle/Services id>   # required for auth
alembic upgrade head            # create/upgrade the SQLite schema
uvicorn app.main:app --reload   # http://localhost:8000  (Swagger at /docs)
pytest
```

All endpoints except `/health` require a Sign in with Apple identity token
(`Authorization: Bearer <token>`); data is scoped per user.

### Apple apps (macOS)

```bash
brew install xcodegen && xcodegen generate   # at repo root → HockeyTracker.xcodeproj
open HockeyTracker.xcodeproj
```

The iOS and watch apps build as one paired project. See [DEVELOPMENT.md](DEVELOPMENT.md).
