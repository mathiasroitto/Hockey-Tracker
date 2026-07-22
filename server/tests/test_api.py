from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.main import app
from app.storage import store

client = TestClient(app)


def _sample_ingest() -> dict:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "date": "2026-07-22",
        "opponent": "Rival HC",
        "location": "Home Rink",
        "periods": 3,
        "events": [
            {"type": "shot", "periodNumber": 1, "timestamp": now},
            {"type": "goal", "periodNumber": 1, "timestamp": now},
            {"type": "assist", "periodNumber": 2, "timestamp": now},
            {"type": "faceoff_win", "periodNumber": 1, "timestamp": now},
            {"type": "faceoff_loss", "periodNumber": 1, "timestamp": now},
        ],
        "shifts": [
            {"periodNumber": 1, "startTime": now, "durationSeconds": 45.0},
            {"periodNumber": 1, "startTime": now, "durationSeconds": 55.0},
        ],
        "biometrics": {
            "avgHeartRate": 155.0,
            "maxHeartRate": 182.0,
            "activeEnergyKcal": 620.0,
            "timeInZonesSeconds": {"zone4": 300.0},
        },
    }


def setup_function() -> None:
    store._games.clear()


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_ingest_and_fetch_game():
    resp = client.post("/games/ingest", json=_sample_ingest())
    assert resp.status_code == 201
    game = resp.json()
    assert game["opponent"] == "Rival HC"

    got = client.get(f"/games/{game['id']}")
    assert got.status_code == 200
    assert got.json()["id"] == game["id"]


def test_game_stats_math():
    game = client.post("/games/ingest", json=_sample_ingest()).json()
    stats = client.get(f"/games/{game['id']}/stats").json()

    assert stats["goals"] == 1
    assert stats["assists"] == 1
    assert stats["points"] == 2
    assert stats["shots"] == 1
    assert stats["shootingPct"] == 1.0  # 1 goal / 1 shot
    assert stats["faceoffPct"] == 0.5  # 1 win / 2 faceoffs
    assert stats["totalIceTimeSeconds"] == 100.0
    assert stats["shiftCount"] == 2
    assert stats["avgShiftSeconds"] == 50.0


def test_career_stats():
    client.post("/games/ingest", json=_sample_ingest())
    client.post("/games/ingest", json=_sample_ingest())
    career = client.get("/stats/career").json()

    assert career["gamesPlayed"] == 2
    assert career["totalGoals"] == 2
    assert career["pointsPerGame"] == 2.0


def test_missing_game_404():
    assert client.get("/games/00000000-0000-0000-0000-000000000000").status_code == 404
