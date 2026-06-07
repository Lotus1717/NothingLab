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


class DailyPageRequest(BaseModel):
    device_id: str = Field(..., min_length=8, max_length=128)
    book_id: Optional[str] = Field(default=None, max_length=64)
    book_title: Optional[str] = Field(default=None, max_length=200)
    book_author: Optional[str] = Field(default=None, max_length=200)
    weread_cookie: Optional[str] = Field(default=None, max_length=4096)
    nonce: int = Field(default=0, ge=0)


class WeReadSyncRequest(BaseModel):
    cookie: str = Field(..., min_length=8, max_length=4096)


class WeReadBookItem(BaseModel):
    book_id: str
    title: str
    author: str = ""
    cover: str = ""


class WeReadSyncResponse(BaseModel):
    books: list[WeReadBookItem]
    count: int


class ReflectionPromptRequest(BaseModel):
    device_id: str = Field(..., min_length=8, max_length=128)
    book_title: str = Field(..., min_length=1, max_length=200)
    content: str = Field(..., min_length=1, max_length=2000)


class ReflectionPromptResponse(BaseModel):
    question: str


class DailyPageResponse(BaseModel):
    book_title: str
    author: str
    content: str
    source_note: str
    date: str
    quota_used: int
    quota_remaining: int
    daily_limit: int


class ErrorResponse(BaseModel):
    detail: str
