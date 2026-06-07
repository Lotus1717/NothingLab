"""远程冒烟测试（需设置 SMOKE_BASE_URL 才会执行）。

示例：
    SMOKE_BASE_URL=http://175.178.249.107 python -m pytest tests/test_remote_smoke.py -v
    SMOKE_SKIP_PROPHECY=1 SMOKE_BASE_URL=http://127.0.0.1:8000 python -m pytest tests/test_remote_smoke.py -v
"""

from __future__ import annotations

import os
import time

import httpx
import pytest

SMOKE_BASE_URL = os.environ.get("SMOKE_BASE_URL", "").rstrip("/")
SKIP_PROPHECY = os.environ.get("SMOKE_SKIP_PROPHECY") == "1"
DEVICE_ID = os.environ.get("SMOKE_DEVICE_ID") or f"auto-smoke-{int(time.time())}"
TIMEOUT = float(os.environ.get("SMOKE_TIMEOUT", "30"))

pytestmark = pytest.mark.skipif(
    not SMOKE_BASE_URL,
    reason="设置 SMOKE_BASE_URL 后运行，例如 SMOKE_BASE_URL=http://175.178.249.107",
)


@pytest.fixture
def client() -> httpx.Client:
    with httpx.Client(base_url=SMOKE_BASE_URL, timeout=TIMEOUT) as c:
        yield c


SENSOR = {
    "battery": 72,
    "brightness": 55,
    "volume": 30,
    "steps": 1234,
    "is_moving": False,
    "ambient_light": 120,
    "is_estimated_ambient_light": True,
    "day_phase": "下午",
    "time_hint": "冒烟测试",
}


def test_health(client: httpx.Client) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert data["deepseek_configured"] is True
    assert data["storage_ok"] is True


def test_quota_valid_device(client: httpx.Client) -> None:
    r = client.get("/v1/quota", params={"device_id": DEVICE_ID})
    assert r.status_code == 200
    data = r.json()
    assert data["device_id"] == DEVICE_ID
    assert data["daily_limit"] >= 1
    assert data["remaining"] >= 0


def test_quota_invalid_device_id(client: httpx.Client) -> None:
    r = client.get("/v1/quota", params={"device_id": "test"})
    assert r.status_code == 422


def test_prophecy_get_not_allowed(client: httpx.Client) -> None:
    r = client.get("/v1/prophecy")
    assert r.status_code == 405


def test_prophecy_post_invalid_body(client: httpx.Client) -> None:
    r = client.post("/v1/prophecy", json={"device_id": "short"})
    assert r.status_code == 422


@pytest.mark.skipif(SKIP_PROPHECY, reason="SMOKE_SKIP_PROPHECY=1")
def test_prophecy_post_success(client: httpx.Client) -> None:
    r = client.post(
        "/v1/prophecy",
        json={"device_id": DEVICE_ID, "nonce": 1, "sensor": SENSOR},
    )
    assert r.status_code in (200, 429), r.text
    if r.status_code == 429:
        pytest.skip("配额已用尽")
    data = r.json()
    assert data["prophecy"].strip()
    assert data["engine"] == "deepseek"
    assert data["quota_used"] >= 1
    assert data["quota_remaining"] >= 0
