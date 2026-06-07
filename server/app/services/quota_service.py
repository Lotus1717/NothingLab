"""基于 SQLite 的每设备每日配额（默认 50 次/自然日）。"""

from __future__ import annotations

import sqlite3
import threading
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

from app.config import Settings, get_settings


class QuotaExceededError(Exception):
    def __init__(self, used: int, daily_limit: int) -> None:
        self.used = used
        self.daily_limit = daily_limit
        super().__init__(f"每日配额已用尽（{used}/{daily_limit}）")


_SCHEMA = """
CREATE TABLE IF NOT EXISTS daily_usage (
    device_id TEXT NOT NULL,
    date TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (device_id, date)
);
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    registered_at TEXT NOT NULL
);
"""


class QuotaService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._lock = threading.Lock()
        db_path = Path(settings.sqlite_path)
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path), check_same_thread=False)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.executescript(_SCHEMA)
        self._conn.commit()

    def close(self) -> None:
        self._conn.close()

    def _today(self) -> str:
        now = datetime.now(self._settings.timezone)
        return now.strftime("%Y-%m-%d")

    def get_usage(self, device_id: str) -> tuple[int, int]:
        with self._lock:
            row = self._conn.execute(
                "SELECT count FROM daily_usage WHERE device_id = ? AND date = ?",
                (device_id, self._today()),
            ).fetchone()
        used = int(row[0]) if row else 0
        remaining = max(self._settings.daily_limit - used, 0)
        return used, remaining

    def get_quota_info(self, device_id: str) -> dict[str, int | str]:
        used, remaining = self.get_usage(device_id)
        return {
            "device_id": device_id,
            "daily_limit": self._settings.daily_limit,
            "used": used,
            "remaining": remaining,
            "date": self._today(),
            "timezone": str(self._settings.timezone),
        }

    def ensure_available(self, device_id: str) -> None:
        """检查配额是否可用，不增加计数（避免 DeepSeek 失败仍扣费）。"""
        used, _ = self.get_usage(device_id)
        if used >= self._settings.daily_limit:
            raise QuotaExceededError(used, self._settings.daily_limit)

    def record_success(self, device_id: str) -> tuple[int, int]:
        """DeepSeek 成功返回后原子递增当日用量。"""
        today = self._today()
        with self._lock:
            row = self._conn.execute(
                "SELECT count FROM daily_usage WHERE device_id = ? AND date = ?",
                (device_id, today),
            ).fetchone()
            current = int(row[0]) if row else 0
            used = current + 1
            if used > self._settings.daily_limit:
                raise QuotaExceededError(current, self._settings.daily_limit)

            if row:
                self._conn.execute(
                    "UPDATE daily_usage SET count = ? WHERE device_id = ? AND date = ?",
                    (used, device_id, today),
                )
            else:
                self._conn.execute(
                    "INSERT INTO daily_usage (device_id, date, count) VALUES (?, ?, 1)",
                    (device_id, today),
                )
            self._conn.commit()

        remaining = max(self._settings.daily_limit - used, 0)
        return used, remaining

    def register_device(self, device_id: str) -> None:
        registered_at = datetime.now(timezone.utc).isoformat()
        with self._lock:
            self._conn.execute(
                """
                INSERT INTO devices (device_id, registered_at)
                VALUES (?, ?)
                ON CONFLICT(device_id) DO UPDATE SET registered_at = excluded.registered_at
                """,
                (device_id, registered_at),
            )
            self._conn.commit()

    def ping(self) -> bool:
        with self._lock:
            self._conn.execute("SELECT 1").fetchone()
        return True


@lru_cache(maxsize=1)
def get_quota_service() -> QuotaService:
    return QuotaService(get_settings())
