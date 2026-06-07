"""FastAPI 应用入口。"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.routers import v1
from app.services.quota_service import get_quota_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    quota = get_quota_service()
    try:
        quota.ping()
        app.state.storage_ok = True
    except Exception:
        app.state.storage_ok = False
    yield


app = FastAPI(
    title="废话预言家 DeepSeek 代理",
    description="为 Flutter 客户端提供安全的 DeepSeek 预言生成与配额管理",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(v1.router)


@app.get("/health")
async def health() -> JSONResponse:
    settings = get_settings()
    storage_ok = getattr(app.state, "storage_ok", False)
    status = "ok" if settings.deepseek_configured and storage_ok else "degraded"
    code = 200 if status == "ok" else 503
    return JSONResponse(
        status_code=code,
        content={
            "status": status,
            "deepseek_configured": settings.deepseek_configured,
            "storage_ok": storage_ok,
        },
    )
