# server/ — FastAPI ingest, storage & processing

Owned by `server-agent`. Implements `contract/openapi.yaml`.

## Layout

```
app/
  main.py      FastAPI app + routes (thin — delegates to the modules below)
  models.py    Pydantic models MIRRORING contract/openapi.yaml
  stats.py     Pure functions: the hockey math (no framework/storage)
  storage.py   GameStore backed by SQLite (SQLModel); swap-able for any DB
tests/         pytest + FastAPI TestClient (isolated in-memory SQLite per test)
```

## Persistence

Games persist to SQLite via SQLModel. Each game is one row: indexed `id` and
`createdAt` columns plus the full contract-shaped `Game` as a JSON `payload`, so
what's stored round-trips exactly to the contract with no ORM mapping to drift.

- Default DB: `sqlite:///./hockey.db` (gitignored). Override with `HOCKEY_DB_URL`
  — e.g. point it at Postgres and nothing else changes.
- Routes get the store via the `get_store` dependency; tests override it with an
  isolated in-memory SQLite (`StaticPool`) so they never touch the real file.
- Moving to a proper relational schema (separate `events`/`shifts` tables) is a
  `storage.py`-only change; routes and the contract stay put.

## Run & test

```bash
cd server
pip install -e ".[dev]"
uvicorn app.main:app --reload      # http://localhost:8000  (/docs for Swagger)
pytest                             # run the test suite
```

## Rules for this component

- `models.py` mirrors the contract exactly. Do **not** invent fields here that
  aren't in `contract/openapi.yaml` — request a contract change instead.
- Keep `main.py` thin. Business logic goes in `stats.py`; persistence behind the
  `GameStore` interface in `storage.py`.
- The in-memory store is a starting point. Replacing it with a real database
  should not require changing the routers — only `storage.py`.
- Every new endpoint gets a test in `tests/`.
