"""Storage abstraction.

Starts as a simple in-memory store so the API is runnable and testable today.
Swap this class for a real database (SQLModel/Postgres, SQLite, etc.) without
touching the routers — that's the point of the interface.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from .models import Game, GameIngest


class GameStore:
    def __init__(self) -> None:
        self._games: dict[UUID, Game] = {}

    def add(self, ingest: GameIngest) -> Game:
        game = Game(**ingest.model_dump(), createdAt=datetime.now(timezone.utc))
        self._games[game.id] = game
        return game

    def get(self, game_id: UUID) -> Game | None:
        return self._games.get(game_id)

    def list(self) -> list[Game]:
        return sorted(self._games.values(), key=lambda g: g.createdAt, reverse=True)


# Process-wide singleton for the in-memory implementation.
store = GameStore()
