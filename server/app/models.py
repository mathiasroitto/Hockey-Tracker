"""Pydantic models mirroring contract/openapi.yaml.

Keep this file in lock-step with the schemas in the contract. If you need a new
shape, change the contract first (contract-agent), then mirror it here.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from enum import Enum
from typing import Annotated
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, PlainSerializer


def _serialize_utc_millis(value: datetime) -> str:
    """Emit ISO-8601 UTC with exactly millisecond precision and a `Z` suffix.

    Apple clients can't reliably parse the 6-digit microsecond precision that
    Pydantic emits by default (e.g. `2026-07-23T22:40:59.110344Z`). This yields
    the canonical `2026-07-23T22:40:59.110Z` — always 3 fractional digits, even
    when microseconds are zero. Naive datetimes are assumed to be UTC.
    """
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    value = value.astimezone(timezone.utc)
    millis = value.microsecond // 1000
    return value.strftime("%Y-%m-%dT%H:%M:%S.") + f"{millis:03d}Z"


# Shared datetime type: every `date-time` field the server emits serializes to
# canonical millisecond-precision UTC. `when_used="json"` keeps python-mode
# access (e.g. stats math) working with real datetime objects.
UtcDateTime = Annotated[
    datetime,
    PlainSerializer(_serialize_utc_millis, return_type=str, when_used="json"),
]


class EventType(str, Enum):
    goal = "goal"
    assist = "assist"
    shot = "shot"
    hit = "hit"
    block = "block"
    penalty = "penalty"
    faceoff_win = "faceoff_win"
    faceoff_loss = "faceoff_loss"
    takeaway = "takeaway"
    giveaway = "giveaway"


class User(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    createdAt: UtcDateTime
    displayName: str | None = None


class UserUpdate(BaseModel):
    """Client-supplied updates to the current user's mutable fields.

    Omitted fields are left unchanged; an explicit null clears the field. Use
    `model_dump(exclude_unset=True)` to preserve the unset-vs-null distinction.
    """

    displayName: str | None = None


class GameEvent(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    type: EventType
    periodNumber: int = Field(ge=1)
    timestamp: UtcDateTime
    note: str | None = None


class Shift(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    periodNumber: int = Field(ge=1)
    startTime: UtcDateTime
    durationSeconds: float = Field(ge=0)


class BiometricSummary(BaseModel):
    avgHeartRate: float
    maxHeartRate: float
    activeEnergyKcal: float = Field(ge=0)
    timeInZonesSeconds: dict[str, float] = Field(default_factory=dict)


class GameIngest(BaseModel):
    date: date
    opponent: str
    location: str | None = None
    periods: int = Field(default=3, ge=1)
    events: list[GameEvent] = Field(default_factory=list)
    shifts: list[Shift] = Field(default_factory=list)
    biometrics: BiometricSummary | None = None


class Game(GameIngest):
    id: UUID = Field(default_factory=uuid4)
    createdAt: UtcDateTime


class GameStats(BaseModel):
    gameId: UUID
    goals: int
    assists: int
    points: int
    shots: int
    shootingPct: float
    hits: int
    blocks: int
    penalties: int
    faceoffPct: float
    totalIceTimeSeconds: float
    shiftCount: int
    # Not in the contract's `required` list, though the server always populates
    # it. Optional here for faithfulness to the contract, not a behavior change.
    avgShiftSeconds: float | None = None
    biometrics: BiometricSummary | None = None


class CareerStats(BaseModel):
    gamesPlayed: int
    totalGoals: int
    totalAssists: int
    totalPoints: int
    pointsPerGame: float
    # Not in the contract's `required` list, though the server always populates
    # them. Optional here for faithfulness to the contract, not a behavior change.
    totalShots: int | None = None
    shootingPct: float | None = None
    avgIceTimeSeconds: float | None = None
