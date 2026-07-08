"""ReflectionPromptService 单元测试（mock DeepSeek）。"""

from unittest.mock import AsyncMock, patch

import pytest

from app.config import Settings
from app.services.reflection_prompt_service import ReflectionPromptService


@pytest.fixture
def settings(monkeypatch: pytest.MonkeyPatch) -> Settings:
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setenv("DEEPSEEK_API_BASE", "https://api.test")
    monkeypatch.setenv("DEEPSEEK_MODEL", "deepseek-chat")
    monkeypatch.setenv("DEEPSEEK_TIMEOUT_SECONDS", "10")
    return Settings()


@pytest.mark.asyncio
async def test_generate_with_explicit_mode(settings: Settings):
    svc = ReflectionPromptService(settings)
    with patch.object(
        svc, "_generate_first_question", new=AsyncMock(return_value="核心观点是什么？")
    ):
        result = await svc.generate(
            "思考，快与慢",
            "系统1和系统2……",
            author="卡尼曼",
            reading_mode="comprehension",
        )

    assert result.question == "核心观点是什么？"
    assert result.reading_mode == "comprehension"
    assert result.mode_label == "理解式"


@pytest.mark.asyncio
async def test_generate_auto_resolves_mode(settings: Settings):
    svc = ReflectionPromptService(settings)
    with patch.object(
        svc._deep,
        "detect_mode",
        new=AsyncMock(
            return_value={
                "reading_mode": "dialectic",
                "confidence": 0.9,
                "reason": "哲学",
            }
        ),
    ), patch.object(
        svc, "_generate_first_question", new=AsyncMock(return_value="作者的前提是什么？")
    ):
        result = await svc.generate("沉思录", "内容", reading_mode="auto")

    assert result.reading_mode == "dialectic"
    assert result.mode_label == "辩证式"


@pytest.mark.asyncio
async def test_fallback_when_no_api_key(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
    settings = Settings()
    svc = ReflectionPromptService(settings)
    result = await svc.generate("三体", "内容", reading_mode="resonance")
    assert result.question
    assert result.reading_mode == "resonance"
