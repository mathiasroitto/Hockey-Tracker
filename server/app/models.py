"""Pydantic models mirroring contract/openapi.yaml.

Keep this file in lock-step with the schemas in the contract. If you need a new
shape, change the contract first (contract-agent), then mirror it here.
"""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


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
    createdAt: datetime
    displayName: str | None = None


class GameEvent(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    type: EventType
    periodNumber: int = Field(ge=1)
    timestamp: datetime
    note: str | None = None


class Shift(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    periodNumber: int = Field(ge=1)
    startTime: datetime
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
    createdAt: datetime


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
    avgShiftSeconds: float
    biometrics: BiometricSummary | None = None


class CareerStats(BaseModel):
    gamesPlayed: int
    totalGoals: int
    totalAssists: int
    totalPoints: int
    totalShots: int
    shootingPct: float
    pointsPerGame: float
    avgIceTimeSeconds: float
