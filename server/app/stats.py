"""Pure functions that derive statistics from stored games.

No storage or framework concerns here — just the hockey math. This keeps the
processing logic easy to test and reason about.
"""

from __future__ import annotations

from .models import CareerStats, EventType, Game, GameStats


def _count(game: Game, event_type: EventType) -> int:
    return sum(1 for e in game.events if e.type == event_type)


def compute_game_stats(game: Game) -> GameStats:
    goals = _count(game, EventType.goal)
    assists = _count(game, EventType.assist)
    shots = _count(game, EventType.shot)
    faceoff_wins = _count(game, EventType.faceoff_win)
    faceoff_losses = _count(game, EventType.faceoff_loss)
    faceoffs = faceoff_wins + faceoff_losses

    total_ice = sum(s.durationSeconds for s in game.shifts)
    shift_count = len(game.shifts)

    return GameStats(
        gameId=game.id,
        goals=goals,
        assists=assists,
        points=goals + assists,
        shots=shots,
        shootingPct=(goals / shots) if shots else 0.0,
        hits=_count(game, EventType.hit),
        blocks=_count(game, EventType.block),
        penalties=_count(game, EventType.penalty),
        faceoffPct=(faceoff_wins / faceoffs) if faceoffs else 0.0,
        totalIceTimeSeconds=total_ice,
        shiftCount=shift_count,
        avgShiftSeconds=(total_ice / shift_count) if shift_count else 0.0,
        biometrics=game.biometrics,
    )


def compute_career_stats(games: list[Game]) -> CareerStats:
    per_game = [compute_game_stats(g) for g in games]
    n = len(per_game)

    total_goals = sum(s.goals for s in per_game)
    total_assists = sum(s.assists for s in per_game)
    total_shots = sum(s.shots for s in per_game)
    total_points = total_goals + total_assists
    total_ice = sum(s.totalIceTimeSeconds for s in per_game)

    return CareerStats(
        gamesPlayed=n,
        totalGoals=total_goals,
        totalAssists=total_assists,
        totalPoints=total_points,
        totalShots=total_shots,
        shootingPct=(total_goals / total_shots) if total_shots else 0.0,
        pointsPerGame=(total_points / n) if n else 0.0,
        avgIceTimeSeconds=(total_ice / n) if n else 0.0,
    )
