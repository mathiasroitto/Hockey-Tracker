"""FastAPI application implementing contract/openapi.yaml."""

from __future__ import annotations

from uuid import UUID

from fastapi import FastAPI, HTTPException

from .models import CareerStats, Game, GameIngest, GameStats
from .stats import compute_career_stats, compute_game_stats
from .storage import store

app = FastAPI(title="Hockey-Tracker API", version="0.1.0")


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/games", response_model=list[Game], tags=["games"])
def list_games() -> list[Game]:
    return store.list()


@app.post("/games/ingest", response_model=Game, status_code=201, tags=["games"])
def ingest_game(payload: GameIngest) -> Game:
    return store.add(payload)


@app.get("/games/{game_id}", response_model=Game, tags=["games"])
def get_game(game_id: UUID) -> Game:
    game = store.get(game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    return game


@app.get("/games/{game_id}/stats", response_model=GameStats, tags=["stats"])
def get_game_stats(game_id: UUID) -> GameStats:
    game = store.get(game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    return compute_game_stats(game)


@app.get("/stats/career", response_model=CareerStats, tags=["stats"])
def get_career_stats() -> CareerStats:
    return compute_career_stats(store.list())
