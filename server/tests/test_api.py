from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, select

from app.auth import get_current_user
from app.main import app, get_store
from app.storage import EventRow, GameStore, ShiftRow, make_engine


@pytest.fixture()
def store():
    # Isolated in-memory SQLite per test. StaticPool keeps a single shared
    # connection so the in-memory DB survives across sessions within the test.
    engine = make_engine("sqlite://", poolclass=StaticPool)
    store = GameStore(engine)
    store.create_tables()  # in-memory DB: build schema directly, no migrations
    return store


@pytest.fixture()
def user(store):
    # A real user row so game FKs resolve; auth itself is stubbed below.
    return store.get_or_create_user("apple-sub-primary")


@pytest.fixture()
def client(store, user):
    # Override both the store and auth: tests never verify a real Apple token.
    app.dependency_overrides[get_store] = lambda: store
    app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(app)
    app.dependency_overrides.clear()


def _as_user(store, user) -> TestClient:
    app.dependency_overrides[get_store] = lambda: store
    app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(app)


def _sample_ingest(opponent: str = "Rival HC", date: str = "2026-07-22") -> dict:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "date": date,
        "opponent": opponent,
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


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_me_returns_current_user(client, user):
    body = client.get("/me").json()
    assert body["id"] == str(user.id)


def _fresh_user_client(store) -> TestClient:
    # get_current_user re-reads the user from the store each request (as real
    # auth does via get_or_create_user), so GET /me reflects PATCH /me writes.
    app.dependency_overrides[get_store] = lambda: store
    app.dependency_overrides[get_current_user] = lambda: store.get_or_create_user(
        "apple-sub-primary"
    )
    return TestClient(app)


def test_patch_me_sets_display_name(store, user):
    try:
        c = _fresh_user_client(store)
        resp = c.patch("/me", json={"displayName": "Wayne"})
        assert resp.status_code == 200
        assert resp.json()["displayName"] == "Wayne"
        assert resp.json()["id"] == str(user.id)

        # A subsequent GET reflects the persisted change.
        assert c.get("/me").json()["displayName"] == "Wayne"
    finally:
        app.dependency_overrides.clear()


def test_patch_me_omitting_field_leaves_value_unchanged(store, user):
    try:
        c = _fresh_user_client(store)
        c.patch("/me", json={"displayName": "Gordie"})

        # Empty body omits displayName → unchanged (not cleared).
        resp = c.patch("/me", json={})
        assert resp.status_code == 200
        assert resp.json()["displayName"] == "Gordie"
        assert c.get("/me").json()["displayName"] == "Gordie"
    finally:
        app.dependency_overrides.clear()


def test_patch_me_explicit_null_clears_value(store, user):
    try:
        c = _fresh_user_client(store)
        c.patch("/me", json={"displayName": "Mario"})

        resp = c.patch("/me", json={"displayName": None})
        assert resp.status_code == 200
        assert resp.json()["displayName"] is None
        assert c.get("/me").json()["displayName"] is None
    finally:
        app.dependency_overrides.clear()


def test_patch_me_requires_authentication(store):
    app.dependency_overrides[get_store] = lambda: store
    try:
        c = TestClient(app)
        assert c.patch("/me", json={"displayName": "Nobody"}).status_code == 401
    finally:
        app.dependency_overrides.clear()


def test_endpoints_require_authentication(store):
    # No get_current_user override: the real auth dependency runs. With no
    # Authorization header it must 401 (offline — never reaches Apple).
    app.dependency_overrides[get_store] = lambda: store
    try:
        c = TestClient(app)
        assert c.get("/health").status_code == 200  # public
        assert c.get("/me").status_code == 401
        assert c.get("/games").status_code == 401
        assert c.get("/stats/career").status_code == 401
        assert c.post("/games/ingest", json=_sample_ingest()).status_code == 401
    finally:
        app.dependency_overrides.clear()


def test_data_is_scoped_per_user(store):
    alice = store.get_or_create_user("apple-sub-alice")
    bob = store.get_or_create_user("apple-sub-bob")
    try:
        alice_game = _as_user(store, alice).post(
            "/games/ingest", json=_sample_ingest(opponent="Alice Opp")
        ).json()
        _as_user(store, bob).post(
            "/games/ingest", json=_sample_ingest(opponent="Bob Opp")
        )

        # Each user sees only their own games.
        assert [g["opponent"] for g in _as_user(store, alice).get("/games").json()] == [
            "Alice Opp"
        ]
        assert [g["opponent"] for g in _as_user(store, bob).get("/games").json()] == [
            "Bob Opp"
        ]

        # Career stats are scoped.
        assert _as_user(store, bob).get("/stats/career").json()["gamesPlayed"] == 1

        # No cross-user access: Bob gets 404 for Alice's game; Alice gets 200.
        gid = alice_game["id"]
        assert _as_user(store, bob).get(f"/games/{gid}").status_code == 404
        assert _as_user(store, bob).get(f"/games/{gid}/stats").status_code == 404
        assert _as_user(store, alice).get(f"/games/{gid}").status_code == 200
    finally:
        app.dependency_overrides.clear()


def test_ingest_and_fetch_game(client):
    resp = client.post("/games/ingest", json=_sample_ingest())
    assert resp.status_code == 201
    game = resp.json()
    assert game["opponent"] == "Rival HC"

    got = client.get(f"/games/{game['id']}")
    assert got.status_code == 200
    assert got.json()["id"] == game["id"]


def test_game_persists_and_round_trips(client):
    game = client.post("/games/ingest", json=_sample_ingest()).json()

    # Full payload survives the DB round-trip, nested shapes intact.
    fetched = client.get(f"/games/{game['id']}").json()
    assert len(fetched["events"]) == 5
    assert len(fetched["shifts"]) == 2
    assert fetched["biometrics"]["maxHeartRate"] == 182.0

    listed = client.get("/games").json()
    assert len(listed) == 1
    assert listed[0]["id"] == game["id"]


def test_events_and_shifts_are_relational_rows(client, store):
    game = client.post("/games/ingest", json=_sample_ingest()).json()

    # Events and shifts live in their own tables, keyed by game_id — directly
    # queryable rather than buried in a JSON blob.
    with Session(store._engine) as session:
        events = session.exec(
            select(EventRow).where(EventRow.game_id == game["id"])
        ).all()
        shifts = session.exec(
            select(ShiftRow).where(ShiftRow.game_id == game["id"])
        ).all()

    assert len(events) == 5
    assert {e.type for e in events} == {
        "shot", "goal", "assist", "faceoff_win", "faceoff_loss"
    }
    assert len(shifts) == 2
    assert sum(s.durationSeconds for s in shifts) == 100.0


def test_game_stats_math(client):
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


def test_filter_by_opponent_case_insensitive(client):
    client.post("/games/ingest", json=_sample_ingest(opponent="Rival HC"))
    client.post("/games/ingest", json=_sample_ingest(opponent="Other HC"))

    games = client.get("/games", params={"opponent": "rival hc"}).json()
    assert len(games) == 1
    assert games[0]["opponent"] == "Rival HC"


def test_filter_by_date_range_inclusive(client):
    client.post("/games/ingest", json=_sample_ingest(date="2026-01-10"))
    client.post("/games/ingest", json=_sample_ingest(date="2026-02-20"))
    client.post("/games/ingest", json=_sample_ingest(date="2026-03-30"))

    # Inclusive on both ends.
    games = client.get("/games", params={"from": "2026-02-20", "to": "2026-03-30"}).json()
    dates = [g["date"] for g in games]
    assert dates == ["2026-03-30", "2026-02-20"]  # newest game date first

    # Open-ended lower bound.
    games = client.get("/games", params={"to": "2026-01-31"}).json()
    assert [g["date"] for g in games] == ["2026-01-10"]


def test_filters_combine_with_and(client):
    client.post("/games/ingest", json=_sample_ingest(opponent="Rival HC", date="2026-01-10"))
    client.post("/games/ingest", json=_sample_ingest(opponent="Rival HC", date="2026-05-01"))
    client.post("/games/ingest", json=_sample_ingest(opponent="Other HC", date="2026-05-01"))

    games = client.get(
        "/games",
        params={"opponent": "Rival HC", "from": "2026-04-01", "to": "2026-06-01"},
    ).json()
    assert len(games) == 1
    assert games[0]["opponent"] == "Rival HC"
    assert games[0]["date"] == "2026-05-01"


def test_no_filters_returns_all_newest_first(client):
    client.post("/games/ingest", json=_sample_ingest(date="2026-01-10"))
    client.post("/games/ingest", json=_sample_ingest(date="2026-03-30"))
    client.post("/games/ingest", json=_sample_ingest(date="2026-02-20"))

    games = client.get("/games").json()
    assert [g["date"] for g in games] == ["2026-03-30", "2026-02-20", "2026-01-10"]


def test_career_stats(client):
    client.post("/games/ingest", json=_sample_ingest())
    client.post("/games/ingest", json=_sample_ingest())
    career = client.get("/stats/career").json()

    assert career["gamesPlayed"] == 2
    assert career["totalGoals"] == 2
    assert career["pointsPerGame"] == 2.0


def test_missing_game_404(client):
    assert client.get("/games/00000000-0000-0000-0000-000000000000").status_code == 404
