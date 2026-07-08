"""DeepReflectionService 单元测试。"""

from unittest.mock import AsyncMock, patch

import pytest

from app.config import Settings
from app.services.deep_reflection_service import DeepReflectionService


@pytest.fixture
def settings(monkeypatch: pytest.MonkeyPatch) -> Settings:
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setenv("DEEPSEEK_API_BASE", "https://api.test")
    monkeypatch.setenv("DEEPSEEK_MODEL", "deepseek-chat")
    monkeypatch.setenv("DEEPSEEK_TIMEOUT_SECONDS", "10")
    return Settings()


@pytest.mark.asyncio
async def test_continue_reflection_parses_json(settings: Settings):
    svc = DeepReflectionService(settings)
    raw = (
        '{"question": "能举一个反例吗？", '
        '"depth_level": 3, "depth_label": "检验", "can_conclude": false}'
    )
    with patch.object(svc, "_call_deepseek", new=AsyncMock(return_value=raw)):
        result = await svc.continue_reflection(
            book_title="思考，快与慢",
            author="",
            content="系统1……",
            reading_mode="comprehension",
            history=[
                {"role": "user", "content": "决策分两种"},
                {"role": "assistant", "content": "核心观点是什么？"},
            ],
        )

    assert result["question"] == "能举一个反例吗？"
    assert result["reading_mode"] == "comprehension"
    assert result["depth_level"] == 3
    assert result["depth_label"] == "检验"
    assert result["can_conclude"] is False


@pytest.mark.asyncio
async def test_estimate_depth_from_history(settings: Settings):
    svc = DeepReflectionService(settings)
    assert svc._estimate_depth("resonance", []) == 1
    assert (
        svc._estimate_depth(
            "resonance",
            [
                {"role": "user", "content": "a"},
                {"role": "assistant", "content": "b"},
                {"role": "user", "content": "c"},
            ],
        )
        == 3
    )


@pytest.mark.asyncio
async def test_fallback_followup_when_json_invalid(settings: Settings):
    svc = DeepReflectionService(settings)
    with patch.object(svc, "_call_deepseek", new=AsyncMock(return_value="not json")):
        result = await svc.continue_reflection(
            book_title="书",
            author="",
            content="内容",
            reading_mode="application",
            history=[{"role": "user", "content": "我的场景是……"}],
        )

    assert result["question"]
    assert result["reading_mode"] == "application"
