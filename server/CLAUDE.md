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

Games persist to SQLite via SQLModel using a normalized relational schema:

```
games   one row per game: scalar fields (date, opponent, location, periods)
        + createdAt, + biometrics summary as a JSON column
events  one row per event, FK game_id → games.id   (indexed)
shifts  one row per shift, FK game_id → games.id    (indexed)
```

Events and shifts are their own tables so they're directly queryable (date
ranges, per-opponent, per-period) rather than locked in a JSON blob. `date` and
`opponent` on `games` are indexed for the same reason. Biometrics stays a JSON
column — it's a single summary per game, not a collection to query across.
`GameStore` reconstructs contract-shaped `Game` objects from these rows; the
add/get/list interface is unchanged, so routes and the contract don't move.

- Default DB: `sqlite:///./hockey.db` (gitignored). Override with `HOCKEY_DB_URL`
  — e.g. point it at Postgres and nothing else changes.
- Routes get the store via the `get_store` dependency; tests override it with an
  isolated in-memory SQLite (`StaticPool`) so they never touch the real file.
- Schema note: `storage.py` deliberately omits `from __future__ import
  annotations` — SQLModel/SQLAlchemy must resolve `Relationship` annotations at
  runtime, and stringized annotations break that resolution.

## Migrations (Alembic)

Alembic owns the real database schema. `GameStore` no longer auto-creates
tables — `create_tables()` exists only for tests/throwaway in-memory DBs.

```bash
alembic upgrade head          # apply migrations (run before first start)
alembic revision --autogenerate -m "describe the change"   # after editing models
alembic downgrade -1          # roll back one revision
alembic current / history     # inspect state
```

Workflow for a schema change:
1. Edit the table models in `storage.py`.
2. `alembic revision --autogenerate -m "..."` and **review** the generated file
   in `alembic/versions/` — autogenerate is a draft, not gospel (it misses some
   changes and can't infer data backfills).
3. `alembic upgrade head`, then run the tests.

Config: `alembic/env.py` points `target_metadata` at `SQLModel.metadata` and
gets its URL from `make_engine()` (so `HOCKEY_DB_URL` applies). `render_as_batch`
is on because SQLite needs batch mode for `ALTER TABLE`. Generated migrations
`import sqlmodel` (via `script.py.mako`) for its column types.

## Run & test

```bash
cd server
pip install -e ".[dev]"
alembic upgrade head               # create/upgrade the database schema
uvicorn app.main:app --reload      # http://localhost:8000  (/docs for Swagger)
pytest                             # run the test suite (uses its own in-memory DB)
```

## Rules for this component

- `models.py` mirrors the contract exactly. Do **not** invent fields here that
  aren't in `contract/openapi.yaml` — request a contract change instead.
- Keep `main.py` thin. Business logic goes in `stats.py`; persistence behind the
  `GameStore` interface in `storage.py`.
- Any change to the table models in `storage.py` needs a matching Alembic
  migration (see above) — don't hand-edit the DB.
- Every new endpoint gets a test in `tests/`.
