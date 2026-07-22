"""Storage layer.

Games are persisted to SQLite via SQLModel using a normalized relational schema:

    games   ← one row per game (scalar fields + biometrics summary as JSON)
    events  ← one row per event, FK game_id → games.id
    shifts  ← one row per shift, FK game_id → games.id

Promoting events and shifts to their own tables makes them directly queryable
(date ranges, per-opponent, per-period) instead of being locked inside a JSON
blob. Biometrics stays a JSON column on the game — it's a single summary object
per game, not a collection to query across.

The `GameStore` API (add/get/list) is unchanged, so the routers and the contract
did not move. Point at another database with HOCKEY_DB_URL.
"""

import os
from datetime import date as date_type, datetime, timezone
from uuid import UUID

from sqlalchemy import Column, DateTime
from sqlalchemy.orm import selectinload
from sqlalchemy.types import JSON
from sqlmodel import Field, Relationship, Session, SQLModel, create_engine, select

from .models import BiometricSummary, Game, GameEvent, GameIngest, Shift

DEFAULT_DB_URL = "sqlite:///./hockey.db"


class EventRow(SQLModel, table=True):
    __tablename__ = "events"

    id: str = Field(primary_key=True)
    game_id: str = Field(foreign_key="games.id", index=True)
    type: str
    periodNumber: int
    timestamp: datetime = Field(sa_column=Column(DateTime(timezone=True), nullable=False))
    note: str | None = None

    game: "GameRow" = Relationship(back_populates="events")


class ShiftRow(SQLModel, table=True):
    __tablename__ = "shifts"

    id: str = Field(primary_key=True)
    game_id: str = Field(foreign_key="games.id", index=True)
    periodNumber: int
    startTime: datetime = Field(sa_column=Column(DateTime(timezone=True), nullable=False))
    durationSeconds: float

    game: "GameRow" = Relationship(back_populates="shifts")


class GameRow(SQLModel, table=True):
    __tablename__ = "games"

    id: str = Field(primary_key=True)
    createdAt: datetime = Field(
        sa_column=Column(DateTime(timezone=True), index=True, nullable=False)
    )
    date: date_type = Field(index=True)
    opponent: str = Field(index=True)
    location: str | None = None
    periods: int = 3
    biometrics: dict | None = Field(default=None, sa_column=Column(JSON))

    events: list[EventRow] = Relationship(
        back_populates="game",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"},
    )
    shifts: list[ShiftRow] = Relationship(
        back_populates="game",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"},
    )


def _as_utc(value: datetime) -> datetime:
    """SQLite returns naive datetimes; treat stored timestamps as UTC."""
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _to_game(row: GameRow) -> Game:
    """Reconstruct a contract `Game` from its rows (call while session is open)."""
    return Game(
        id=UUID(row.id),
        createdAt=_as_utc(row.createdAt),
        date=row.date,
        opponent=row.opponent,
        location=row.location,
        periods=row.periods,
        biometrics=BiometricSummary(**row.biometrics) if row.biometrics else None,
        events=[
            GameEvent(
                id=UUID(e.id),
                type=e.type,
                periodNumber=e.periodNumber,
                timestamp=_as_utc(e.timestamp),
                note=e.note,
            )
            for e in row.events
        ],
        shifts=[
            Shift(
                id=UUID(s.id),
                periodNumber=s.periodNumber,
                startTime=_as_utc(s.startTime),
                durationSeconds=s.durationSeconds,
            )
            for s in row.shifts
        ],
    )


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
            date=game.date,
            opponent=game.opponent,
            location=game.location,
            periods=game.periods,
            biometrics=(
                game.biometrics.model_dump(mode="json") if game.biometrics else None
            ),
            events=[
                EventRow(
                    id=str(e.id),
                    type=e.type.value,
                    periodNumber=e.periodNumber,
                    timestamp=e.timestamp,
                    note=e.note,
                )
                for e in game.events
            ],
            shifts=[
                ShiftRow(
                    id=str(s.id),
                    periodNumber=s.periodNumber,
                    startTime=s.startTime,
                    durationSeconds=s.durationSeconds,
                )
                for s in game.shifts
            ],
        )
        with Session(self._engine) as session:
            session.add(row)
            session.commit()
        return game

    def get(self, game_id: UUID) -> Game | None:
        with Session(self._engine) as session:
            row = session.get(GameRow, str(game_id))
            return _to_game(row) if row else None

    def list(self) -> list[Game]:
        with Session(self._engine) as session:
            rows = session.exec(
                select(GameRow)
                .options(selectinload(GameRow.events), selectinload(GameRow.shifts))
                .order_by(GameRow.createdAt.desc())
            ).all()
            return [_to_game(row) for row in rows]
