"""传感器数据模型（与 Flutter SensorData 字段对齐）。"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SensorPayload(BaseModel):
    battery: Optional[int] = Field(default=None, ge=0, le=100)
    charging: bool = False
    brightness: int = Field(default=50, ge=0, le=100)
    volume: int = Field(default=50, ge=0, le=100)
    steps: int = Field(default=0, ge=0)
    is_moving: bool = False
    ambient_light: int = Field(default=0, ge=0)
    is_real_battery: bool = False
    is_real_volume: bool = False
    is_real_motion: bool = False
    is_real_steps: bool = False
    is_real_ambient_light: bool = False
    is_estimated_ambient_light: bool = False
    time_hint: str = ""
    day_phase: str = ""
    timestamp: Optional[datetime] = None

    def with_current_time_hints(self) -> "SensorPayload":
        now = datetime.now()
        return self.model_copy(
            update={
                "timestamp": now,
                "time_hint": self.time_hint or _time_hint_for(now),
                "day_phase": self.day_phase or _day_phase_for(now),
            }
        )


def _time_hint_for(now: datetime) -> str:
    h = now.hour
    if h < 6:
        return "凌晨发呆模式"
    if h < 9:
        return "刚睡醒迷糊中"
    if h < 12:
        return "上午搬砖中"
    if h < 14:
        return "午饭消化期"
    if h < 18:
        return "下午摸鱼中"
    if h < 22:
        return "晚上放松中"
    return "深夜修仙中"


def _day_phase_for(now: datetime) -> str:
    h = now.hour
    if 6 <= h < 12:
        return "早晨"
    if 12 <= h < 14:
        return "中午"
    if 14 <= h < 18:
        return "下午"
    if 18 <= h < 22:
        return "傍晚"
    return "夜晚"
