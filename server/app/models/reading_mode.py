"""阅读思考模式 — 四种 AI 引导策略。"""

from __future__ import annotations

from typing import Literal

ReadingModeValue = Literal[
    "auto", "resonance", "comprehension", "dialectic", "application"
]
ResolvedReadingMode = Literal[
    "resonance", "comprehension", "dialectic", "application"
]

MODE_LABELS: dict[str, str] = {
    "resonance": "共鸣式",
    "comprehension": "理解式",
    "dialectic": "辩证式",
    "application": "应用式",
}

DEPTH_STAGES: dict[str, list[str]] = {
    "resonance": ["触动", "连接", "细节", "提炼", "行动"],
    "comprehension": ["复述", "联系", "检验", "应用"],
    "dialectic": ["概念", "论证", "质疑", "立场"],
    "application": ["场景", "诊断", "方法", "计划"],
}

CONFIDENCE_THRESHOLD = 0.7
DEFAULT_MODE: ResolvedReadingMode = "resonance"

RESOLVED_MODES: tuple[str, ...] = (
    "resonance",
    "comprehension",
    "dialectic",
    "application",
)


def resolve_mode(
    requested: str,
    detected: str | None = None,
    confidence: float = 0.0,
) -> ResolvedReadingMode:
    if requested in RESOLVED_MODES:
        return requested  # type: ignore[return-value]
    if detected in RESOLVED_MODES and confidence >= CONFIDENCE_THRESHOLD:
        return detected  # type: ignore[return-value]
    return DEFAULT_MODE


def depth_label(mode: str, depth_level: int) -> str:
    stages = DEPTH_STAGES.get(mode, DEPTH_STAGES[DEFAULT_MODE])
    idx = max(0, min(depth_level - 1, len(stages) - 1))
    return stages[idx]
