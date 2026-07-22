"""FastAPI application implementing contract/openapi.yaml."""

from __future__ import annotations

from datetime import date
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Query

from .models import CareerStats, Game, GameIngest, GameStats
from .stats import compute_career_stats, compute_game_stats
from .storage import GameStore, make_engine

app = FastAPI(title="Hockey-Tracker API", version="0.2.0")

# Process-wide store backed by SQLite (or HOCKEY_DB_URL). Overridable in tests
# via app.dependency_overrides[get_store].
_store = GameStore(make_engine())


def get_store() -> GameStore:
    return _store


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/games", response_model=list[Game], tags=["games"])
def list_games(
    store: GameStore = Depends(get_store),
    opponent: str | None = Query(
        default=None, description="Case-insensitive exact match on opponent name."
    ),
    date_from: date | None = Query(
        default=None, alias="from", description="Only games on or after this date."
    ),
    date_to: date | None = Query(
        default=None, alias="to", description="Only games on or before this date."
    ),
) -> list[Game]:
    return store.list(opponent=opponent, date_from=date_from, date_to=date_to)


@app.post("/games/ingest", response_model=Game, status_code=201, tags=["games"])
def ingest_game(payload: GameIngest, store: GameStore = Depends(get_store)) -> Game:
    return store.add(payload)


@app.get("/games/{game_id}", response_model=Game, tags=["games"])
def get_game(game_id: UUID, store: GameStore = Depends(get_store)) -> Game:
    game = store.get(game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    return game


@app.get("/games/{game_id}/stats", response_model=GameStats, tags=["stats"])
def get_game_stats(game_id: UUID, store: GameStore = Depends(get_store)) -> GameStats:
    game = store.get(game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    return compute_game_stats(game)


@app.get("/stats/career", response_model=CareerStats, tags=["stats"])
def get_career_stats(store: GameStore = Depends(get_store)) -> CareerStats:
    return compute_career_stats(store.list())
