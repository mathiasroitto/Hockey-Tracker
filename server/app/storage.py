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

from sqlalchemy import Column, DateTime, func
from sqlalchemy.orm import selectinload
from sqlalchemy.types import JSON
from sqlmodel import Field, Relationship, Session, SQLModel, create_engine, select

from .models import BiometricSummary, Game, GameEvent, GameIngest, Shift, User

DEFAULT_DB_URL = "sqlite:///./hockey.db"


class UserRow(SQLModel, table=True):
    __tablename__ = "users"

    id: str = Field(primary_key=True)
    apple_sub: str = Field(unique=True, index=True)
    createdAt: datetime = Field(sa_column=Column(DateTime(timezone=True), nullable=False))
    displayName: str | None = None


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
    user_id: str = Field(foreign_key="users.id", index=True)
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

    def create_tables(self) -> None:
        """Create tables directly from metadata.

        For tests and throwaway/in-memory databases. Real databases are managed
        by Alembic migrations (`alembic upgrade head`) — do not call this there.
        """
        SQLModel.metadata.create_all(self._engine)

    # --- users -----------------------------------------------------------

    def get_or_create_user(self, apple_sub: str) -> User:
        """Return the user for this Apple `sub`, creating them on first sign-in."""
        with Session(self._engine) as session:
            row = session.exec(
                select(UserRow).where(UserRow.apple_sub == apple_sub)
            ).first()
            if row is None:
                user = User(createdAt=datetime.now(timezone.utc))
                row = UserRow(
                    id=str(user.id),
                    apple_sub=apple_sub,
                    createdAt=user.createdAt,
                )
                session.add(row)
                session.commit()
                return user
            return User(
                id=UUID(row.id),
                createdAt=_as_utc(row.createdAt),
                displayName=row.displayName,
            )

    def update_user(self, user_id: UUID, fields: dict) -> User:
        """Set only the provided mutable fields on this user, return the result.

        `fields` should already reflect the request's unset-vs-null distinction
        (i.e. built via `UserUpdate.model_dump(exclude_unset=True)`), so an
        omitted key leaves the column unchanged and an explicit None clears it.
        """
        with Session(self._engine) as session:
            row = session.get(UserRow, str(user_id))
            if row is None:
                raise KeyError(user_id)
            for key, value in fields.items():
                setattr(row, key, value)
            session.add(row)
            session.commit()
            session.refresh(row)
            return User(
                id=UUID(row.id),
                createdAt=_as_utc(row.createdAt),
                displayName=row.displayName,
            )

    # --- games (scoped to a user) ---------------------------------------

    def add(self, user_id: UUID, ingest: GameIngest) -> Game:
        game = Game(**ingest.model_dump(), createdAt=datetime.now(timezone.utc))
        row = GameRow(
            id=str(game.id),
            user_id=str(user_id),
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

    def get(self, user_id: UUID, game_id: UUID) -> Game | None:
        """Return the game only if it belongs to this user, else None."""
        with Session(self._engine) as session:
            row = session.get(GameRow, str(game_id))
            if row is None or row.user_id != str(user_id):
                return None
            return _to_game(row)

    def list(
        self,
        user_id: UUID,
        *,
        opponent: str | None = None,
        date_from: date_type | None = None,
        date_to: date_type | None = None,
    ) -> list[Game]:
        """Return this user's games newest-first, with optional filters (AND).

        `opponent` is a case-insensitive exact match; `date_from`/`date_to` are
        an inclusive range on the game date. All filters hit indexed columns.
        """
        statement = (
            select(GameRow)
            .where(GameRow.user_id == str(user_id))
            .options(selectinload(GameRow.events), selectinload(GameRow.shifts))
            .order_by(GameRow.date.desc(), GameRow.createdAt.desc())
        )
        if opponent is not None:
            statement = statement.where(
                func.lower(GameRow.opponent) == opponent.lower()
            )
        if date_from is not None:
            statement = statement.where(GameRow.date >= date_from)
        if date_to is not None:
            statement = statement.where(GameRow.date <= date_to)

        with Session(self._engine) as session:
            rows = session.exec(statement).all()
            return [_to_game(row) for row in rows]
