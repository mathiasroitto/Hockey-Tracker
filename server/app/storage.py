"""Storage layer.

Games are persisted to SQLite via SQLModel. Each game is stored as one row with
its full contract-shaped payload in a JSON column, so what we store round-trips
exactly to `Game` in the contract — no field-by-field ORM mapping to drift.

The `GameStore` API (add/get/list) is unchanged from the earlier in-memory
version, so the routers didn't have to change. Point it at a different database
by setting HOCKEY_DB_URL (e.g. a Postgres URL) — nothing else moves.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import Column, DateTime
from sqlalchemy.types import JSON
from sqlmodel import Field, Session, SQLModel, create_engine, select

from .models import Game, GameIngest

DEFAULT_DB_URL = "sqlite:///./hockey.db"


class GameRow(SQLModel, table=True):
    """One game, stored with its full JSON payload plus indexed columns."""

    __tablename__ = "games"

    id: str = Field(primary_key=True)
    createdAt: datetime = Field(
        sa_column=Column(DateTime(timezone=True), index=True, nullable=False)
    )
    payload: dict = Field(sa_column=Column(JSON, nullable=False))


def make_engine(url: str | None = None, **kwargs):
    """Build an engine, defaulting to the local SQLite file (or HOCKEY_DB_URL)."""
    url = url or os.environ.get("HOCKEY_DB_URL", DEFAULT_DB_URL)
    connect_args = {"check_same_thread": False} if url.startswith("sqlite") else {}
    return create_engine(url, connect_args=connect_args, **kwargs)


class GameStore:
    def __init__(self, engine) -> None:
        self._engine = engine
        SQLModel.metadata.create_all(engine)

    def add(self, ingest: GameIngest) -> Game:
        game = Game(**ingest.model_dump(), createdAt=datetime.now(timezone.utc))
        row = GameRow(
            id=str(game.id),
            createdAt=game.createdAt,
            payload=game.model_dump(mode="json"),
        )
        with Session(self._engine) as session:
            session.add(row)
            session.commit()
        return game

    def get(self, game_id: UUID) -> Game | None:
        with Session(self._engine) as session:
            row = session.get(GameRow, str(game_id))
            return Game.model_validate(row.payload) if row else None

    def list(self) -> list[Game]:
        with Session(self._engine) as session:
            rows = session.exec(
                select(GameRow).order_by(GameRow.createdAt.desc())
            ).all()
            return [Game.model_validate(row.payload) for row in rows]
