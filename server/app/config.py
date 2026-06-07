"""环境变量与运行配置。"""

from __future__ import annotations

import os
from functools import lru_cache
from zoneinfo import ZoneInfo


@lru_cache
def get_settings() -> "Settings":
    return Settings()


class Settings:
    def __init__(self) -> None:
        self.deepseek_api_key: str = os.environ.get("DEEPSEEK_API_KEY", "").strip()
        self.deepseek_api_base: str = os.environ.get(
            "DEEPSEEK_API_BASE", "https://api.deepseek.com"
        ).rstrip("/")
        self.deepseek_model: str = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
        self.deepseek_timeout_seconds: int = int(
            os.environ.get("DEEPSEEK_TIMEOUT_SECONDS", "30")
        )
        data_dir = os.environ.get("DATA_DIR", "").strip()
        sqlite_path = os.environ.get("SQLITE_PATH", "").strip()
        if sqlite_path:
            self.sqlite_path = sqlite_path
        elif data_dir:
            self.sqlite_path = os.path.join(data_dir, "quota.db")
        else:
            self.sqlite_path = "./data/quota.db"
        self.daily_limit: int = int(os.environ.get("DAILY_LIMIT", "50"))
        self.timezone: ZoneInfo = ZoneInfo(
            os.environ.get("QUOTA_TIMEZONE", "Asia/Shanghai")
        )
        self.port: int = int(os.environ.get("PORT", "8000"))
        self.register_api_key: str | None = os.environ.get("REGISTER_API_KEY") or None

    @property
    def deepseek_configured(self) -> bool:
        return bool(self.deepseek_api_key)
