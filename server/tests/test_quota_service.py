"""quota_service 单元测试。"""

from __future__ import annotations

import os
import tempfile
from datetime import datetime
from unittest.mock import patch
from zoneinfo import ZoneInfo

import pytest

from app.config import Settings
from app.services.quota_service import QuotaExceededError, QuotaService


@pytest.fixture
def quota_service() -> QuotaService:
    with tempfile.TemporaryDirectory() as tmp:
        db_path = os.path.join(tmp, "quota.db")
        settings = Settings()
        settings.sqlite_path = db_path
        settings.daily_limit = 3
        settings.timezone = ZoneInfo("Asia/Shanghai")
        service = QuotaService(settings)
        yield service
        service.close()


def test_record_success_increments(quota_service: QuotaService) -> None:
    device_id = "test-device-001"
    assert quota_service.get_usage(device_id) == (0, 3)

    used, remaining = quota_service.record_success(device_id)
    assert used == 1
    assert remaining == 2
    assert quota_service.get_usage(device_id) == (1, 2)


def test_ensure_available_blocks_at_limit(quota_service: QuotaService) -> None:
    device_id = "test-device-002"
    for _ in range(3):
        quota_service.record_success(device_id)

    with pytest.raises(QuotaExceededError) as exc:
        quota_service.ensure_available(device_id)
    assert exc.value.used == 3
    assert exc.value.daily_limit == 3


def test_record_success_raises_at_limit(quota_service: QuotaService) -> None:
    device_id = "test-device-003"
    for _ in range(3):
        quota_service.record_success(device_id)

    with pytest.raises(QuotaExceededError):
        quota_service.record_success(device_id)


def test_daily_reset_by_date(quota_service: QuotaService) -> None:
    device_id = "test-device-004"
    quota_service.record_success(device_id)
    assert quota_service.get_usage(device_id)[0] == 1

    tomorrow = datetime(2026, 6, 8, 10, 0, tzinfo=ZoneInfo("Asia/Shanghai"))

    with patch.object(quota_service, "_today", return_value="2026-06-08"):
        assert quota_service.get_usage(device_id) == (0, 3)
        used, remaining = quota_service.record_success(device_id)
        assert used == 1
        assert remaining == 2

    # 回到「今天」仍保留昨日计数（模拟跨日查询历史日逻辑由 date 键隔离）
    with patch.object(quota_service, "_today", return_value="2026-06-07"):
        assert quota_service.get_usage(device_id)[0] == 1


def test_register_device(quota_service: QuotaService) -> None:
    device_id = "test-device-005"
    quota_service.register_device(device_id)
    row = quota_service._conn.execute(
        "SELECT registered_at FROM devices WHERE device_id = ?",
        (device_id,),
    ).fetchone()
    assert row is not None
    assert row[0]


def test_ping(quota_service: QuotaService) -> None:
    assert quota_service.ping() is True
