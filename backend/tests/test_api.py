import os
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.pop("FREELLMAPI_API_KEY", None)
os.environ.pop("GROQ_API_KEY", None)

import main  # noqa: E402

client = TestClient(main.app)


def test_root_and_health():
    assert client.get("/").status_code == 200
    assert client.get("/health").json() == {"status": "ok"}


def test_security_headers_present():
    r = client.get("/health")
    assert r.headers["x-content-type-options"] == "nosniff"
    assert r.headers["x-frame-options"] == "DENY"


def test_cors_does_not_allow_credentials():
    r = client.options(
        "/api/chat",
        headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "POST"},
    )
    assert r.headers.get("access-control-allow-credentials") != "true"


def test_nearby_validates_coordinates():
    assert client.get("/api/pujas/nearby", params={"lat": 22.57, "lon": 88.36}).status_code == 200
    assert client.get("/api/pujas/nearby", params={"lat": 999, "lon": 88.36}).status_code == 422
    assert client.get("/api/pujas/nearby", params={"lat": 22.5, "lon": 88.3, "radius_m": -1}).status_code == 422


def test_session_sync_validation_and_read_disabled():
    ok = {"session_id": "pujo_123456789_abcdef", "bookmarked_ids": ["a", "b"]}
    assert client.post("/api/session/sync", json=ok).status_code == 200
    bad = {"session_id": "../../etc/passwd"}
    assert client.post("/api/session/sync", json=bad).status_code == 422
    too_many = {"session_id": "pujo_123456789_abcdef", "visited_ids": ["x"] * 601}
    assert client.post("/api/session/sync", json=too_many).status_code == 422
    # Session read-back is disabled by default (IDOR protection)
    assert client.get("/api/session/pujo_123456789_abcdef").status_code == 404


def test_chat_validation():
    assert client.post("/api/chat", json={"query": "", "lat": 22.5, "lon": 88.3}).status_code == 422
    assert client.post("/api/chat", json={"query": "x" * 1001, "lat": 22.5, "lon": 88.3}).status_code == 422


def test_chat_without_key_falls_back_gracefully():
    r = client.post("/api/chat", json={"query": "where is ekdalia", "lat": 22.5, "lon": 88.3})
    assert r.status_code == 200
    body = r.json()
    assert "display_text" in body
    assert "freellmapi" not in r.text


def test_parse_and_validate_action_rejects_unknown_actions():
    text, action = main.parse_and_validate_action("hi [ACTION:DELETE_ALL|x=1]")
    assert action is None and "ACTION" not in text
    _, action = main.parse_and_validate_action("[ACTION:OPEN_MAP|lat=22.5&lng=88.3&name=Ekdalia]")
    assert action["action"] == "OPEN_MAP"


def test_bounded_store_evicts_oldest():
    from collections import OrderedDict
    store = OrderedDict()
    for i in range(5):
        main._bounded_put(store, i, i, 3)
    assert list(store.keys()) == [2, 3, 4]
