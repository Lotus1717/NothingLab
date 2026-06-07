"""v1 API 路由 — 废话预言家 + 每天拆一页。"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.config import Settings, get_settings
from app.models.schemas import (
    DailyPageRequest,
    DailyPageResponse,
    ProphecyRequest,
    ProphecyResponse,
    QuotaResponse,
    ReflectionPromptRequest,
    ReflectionPromptResponse,
    RegisterRequest,
    RegisterResponse,
    WeReadBookItem,
    WeReadSyncRequest,
    WeReadSyncResponse,
)
from app.services.daily_page_service import DailyPageError, DailyPageService
from app.services.deepseek_client import DeepSeekClient, DeepSeekError
from app.services.prophecy_service import generate_with_quality_gate
from app.services.quota_service import QuotaExceededError, QuotaService, get_quota_service
from app.services.reflection_prompt_service import ReflectionPromptService
from app.services.weread_client import WeReadError, sync_shelf

router = APIRouter(prefix="/v1", tags=["v1"])


def _quota_service() -> QuotaService:
    return get_quota_service()


def _deepseek_client(settings: Settings = Depends(get_settings)) -> DeepSeekClient:
    return DeepSeekClient(settings)


def _daily_page_service(settings: Settings = Depends(get_settings)) -> DailyPageService:
    return DailyPageService(settings)


def _reflection_prompt_service(
    settings: Settings = Depends(get_settings),
) -> ReflectionPromptService:
    return ReflectionPromptService(settings)


@router.post("/daily-page", response_model=DailyPageResponse)
async def create_daily_page(
    body: DailyPageRequest,
    quota: QuotaService = Depends(_quota_service),
    daily: DailyPageService = Depends(_daily_page_service),
    settings: Settings = Depends(get_settings),
) -> DailyPageResponse:
    if not settings.deepseek_configured:
        raise HTTPException(status_code=503, detail="DeepSeek API 未配置")

    used, remaining = 0, settings.daily_limit
    if body.nonce == 0:
        try:
            quota.ensure_available(body.device_id)
        except QuotaExceededError as exc:
            raise HTTPException(
                status_code=429,
                detail=f"每日配额已用尽（{exc.used}/{exc.daily_limit}）",
            ) from exc

    try:
        page = await daily.generate(
            book_id=body.book_id,
            book_title=body.book_title,
            book_author=body.book_author,
            weread_cookie=body.weread_cookie,
            nonce=body.nonce,
        )
    except DailyPageError as exc:
        raise HTTPException(status_code=502, detail=exc.message) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    if body.nonce == 0:
        try:
            used, remaining = quota.record_success(body.device_id)
        except QuotaExceededError:
            used, remaining = 0, 0

    return DailyPageResponse(
        book_title=page.book_title,
        author=page.author,
        content=page.content,
        source_note=page.source_note,
        date=date.today().isoformat(),
        quota_used=used,
        quota_remaining=remaining,
        daily_limit=settings.daily_limit,
    )


@router.post("/prophecy", response_model=ProphecyResponse)
async def create_prophecy(
    body: ProphecyRequest,
    quota: QuotaService = Depends(_quota_service),
    deepseek: DeepSeekClient = Depends(_deepseek_client),
    settings: Settings = Depends(get_settings),
) -> ProphecyResponse:
    if not settings.deepseek_configured:
        raise HTTPException(status_code=503, detail="DeepSeek API 未配置")

    try:
        quota.ensure_available(body.device_id)
    except QuotaExceededError as exc:
        raise HTTPException(
            status_code=429,
            detail=f"每日配额已用尽（{exc.used}/{exc.daily_limit}）",
        ) from exc

    sensor = body.sensor.with_current_time_hints()
    try:
        prophecy = await generate_with_quality_gate(
            deepseek, sensor, nonce=body.nonce
        )
    except DeepSeekError as exc:
        raise HTTPException(status_code=502, detail=exc.message) from exc

    if not prophecy:
        raise HTTPException(status_code=502, detail="预言生成失败，请稍后重试")

    try:
        used, remaining = quota.record_success(body.device_id)
    except QuotaExceededError as exc:
        raise HTTPException(
            status_code=429,
            detail=f"每日配额已用尽（{exc.used}/{exc.daily_limit}）",
        ) from exc

    return ProphecyResponse(
        prophecy=prophecy,
        engine="deepseek",
        quota_used=used,
        quota_remaining=remaining,
        daily_limit=settings.daily_limit,
    )


@router.post("/register", response_model=RegisterResponse)
async def register_device(
    body: RegisterRequest,
    request: Request,
    quota: QuotaService = Depends(_quota_service),
    settings: Settings = Depends(get_settings),
) -> RegisterResponse:
    if settings.register_api_key:
        auth = request.headers.get("Authorization", "")
        expected = f"Bearer {settings.register_api_key}"
        if auth != expected:
            raise HTTPException(status_code=401, detail="注册接口未授权")

    device_id = body.device_id or str(uuid.uuid4())
    quota.register_device(device_id)
    return RegisterResponse(
        device_id=device_id,
        registered_at=datetime.now(timezone.utc),
    )


@router.get("/quota", response_model=QuotaResponse)
async def get_quota(
    device_id: str = Query(..., min_length=8, max_length=128),
    quota: QuotaService = Depends(_quota_service),
) -> QuotaResponse:
    info = quota.get_quota_info(device_id)
    return QuotaResponse(**info)


@router.post("/weread/sync", response_model=WeReadSyncResponse)
async def sync_weread_shelf(body: WeReadSyncRequest) -> WeReadSyncResponse:
    try:
        books = await sync_shelf(body.cookie)
    except WeReadError as exc:
        raise HTTPException(status_code=400, detail=exc.message) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"微信读书同步失败: {exc}") from exc

    items = [WeReadBookItem(**book) for book in books]
    return WeReadSyncResponse(books=items, count=len(items))


@router.post("/reflection-prompt", response_model=ReflectionPromptResponse)
async def create_reflection_prompt(
    body: ReflectionPromptRequest,
    prompt_svc: ReflectionPromptService = Depends(_reflection_prompt_service),
) -> ReflectionPromptResponse:
    question = await prompt_svc.generate(body.book_title, body.content)
    return ReflectionPromptResponse(question=question)
