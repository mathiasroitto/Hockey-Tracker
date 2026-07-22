# Hockey-Tracker

A personal hockey performance tracking system in three parts, plus a shared
data contract that binds them together.

## The system

| Component      | Runtime            | Responsibility                                              |
| -------------- | ------------------ | ---------------------------------------------------------- |
| `watch-app/`   | watchOS (SwiftUI)  | Capture during games: shifts, events, HealthKit biometrics |
| `ios-app/`     | iOS/iPadOS SwiftUI | View statistics per game and over time                      |
| `server/`      | Python / FastAPI   | Ingest, store, and process/aggregate game data             |
| `contract/`    | OpenAPI (language-neutral) | The single source of truth for data shapes + API   |

Data flows **Watch → phone → server**, and stats flow back **server → phone**.

## The way of working: one agent per bounded context

Each top-level directory is owned by a dedicated subagent (see `.claude/agents/`).
The rules that keep parallel work from drifting:

1. **The contract is sacred.** `contract/openapi.yaml` is the source of truth for
   every data shape and endpoint. Watch, iOS, and server all *consume* it. Only
   `contract-agent` changes it, and every change is deliberate and versioned in
   `contract/CHANGELOG.md`.
2. **Stay in your lane.** An agent edits only its own directory. If it needs a
   schema or endpoint change, it does **not** patch around it locally — it
   requests a contract change and defers to `contract-agent`.
3. **Contract-first.** New features start by defining the data/endpoint shape in
   `contract/`, then the three sides implement against it independently.
4. **The contract must always be implementable on all three sides.** Before
   changing it, consider Watch (capture), iOS (display), and server (storage).

## Conventions

- Semantic versioning on the contract (`info.version` in `openapi.yaml`).
- Timestamps are ISO-8601 UTC. Durations are in seconds. IDs are UUID strings.
- Prefer additive, backward-compatible contract changes; breaking changes bump
  the major version and are called out in the changelog.
