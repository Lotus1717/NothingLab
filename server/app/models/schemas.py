"""API 请求与响应模型。"""

from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field

from app.models.sensor import SensorPayload


class ProphecyRequest(BaseModel):
    device_id: str = Field(..., min_length=8, max_length=128)
    sensor: SensorPayload
    nonce: int = Field(default=0, ge=0)


class ProphecyResponse(BaseModel):
    prophecy: str
    engine: Literal["deepseek", "rejected"]
    quota_used: int
    quota_remaining: int
    daily_limit: int


class RegisterRequest(BaseModel):
    device_id: Optional[str] = Field(default=None, min_length=8, max_length=128)


class RegisterResponse(BaseModel):
    device_id: str
    registered_at: datetime


class QuotaResponse(BaseModel):
    device_id: str
    daily_limit: int
    used: int
    remaining: int
    date: str
    timezone: str


class ErrorResponse(BaseModel):
    detail: str
