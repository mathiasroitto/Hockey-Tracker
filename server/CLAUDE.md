# server/ — FastAPI ingest, storage & processing

Owned by `server-agent`. Implements `contract/openapi.yaml`.

## Layout

```
app/
  main.py      FastAPI app + routes (thin — delegates to the modules below)
  models.py    Pydantic models MIRRORING contract/openapi.yaml
  stats.py     Pure functions: the hockey math (no framework/storage)
  storage.py   GameStore interface + in-memory implementation
tests/         pytest + FastAPI TestClient
```

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
