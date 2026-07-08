"""AI 辅助提问 — 按阅读模式引导写感想，不代写。"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass

import httpx

from app.config import Settings
from app.models.reading_mode import MODE_LABELS, resolve_mode
from app.services.deep_reflection_service import DeepReflectionService
from app.services.reflection_prompt_builder import (
    BASE_RULES,
    build_first_turn_user,
    FALLBACK_FIRST,
    MODE_FIRST_TURN,
)


@dataclass
class FirstQuestionResult:
    question: str
    reading_mode: str
    mode_label: str


class ReflectionPromptService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._deep = DeepReflectionService(settings)

    async def generate(
        self,
        book_title: str,
        content: str,
        *,
        author: str = "",
        reading_mode: str = "auto",
    ) -> FirstQuestionResult:
        resolved = reading_mode
        if reading_mode == "auto":
            detected = await self._deep.detect_mode(book_title, author, content)
            resolved = resolve_mode(
                "auto",
                str(detected.get("reading_mode")),
                float(detected.get("confidence", 0)),
            )

        question = await self._generate_first_question(
            resolved, book_title, author, content
        )
        return FirstQuestionResult(
            question=question,
            reading_mode=resolved,
            mode_label=MODE_LABELS.get(resolved, "共鸣式"),
        )

    async def _generate_first_question(
        self, mode: str, book_title: str, author: str, content: str
    ) -> str:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            return self._fallback(mode, book_title, content)

        system = f"{MODE_FIRST_TURN.get(mode, MODE_FIRST_TURN['resonance'])}\n\n{BASE_RULES}\n直接输出问题文本，不要 JSON、不要引号。"
        user_msg = build_first_turn_user(mode, book_title, author, content)
        raw = await self._call_deepseek_text(system, user_msg)
        raw = re.sub(r"^[「『\"']|[」』\"']$", "", raw)
        return raw if raw else self._fallback(mode, book_title, content)

    async def _call_deepseek_text(self, system: str, user: str) -> str:
        url = f"{self._settings.deepseek_api_base}/chat/completions"
        payload = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.9,
            "max_tokens": 80,
            "stream": False,
        }
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._settings.deepseek_api_key}",
        }

        async with httpx.AsyncClient(
            timeout=self._settings.deepseek_timeout_seconds
        ) as client:
            response = await client.post(url, json=payload, headers=headers)

        if response.status_code != 200:
            return ""

        decoded = response.json()
        choices = decoded.get("choices") or []
        if not choices:
            return ""

        raw = choices[0].get("message", {}).get("content", "").strip()
        parsed = self._try_parse_question_json(raw)
        return parsed or raw

    @staticmethod
    def _try_parse_question_json(raw: str) -> str:
        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                q = data.get("question")
                if isinstance(q, str) and q.strip():
                    return q.strip()
        except json.JSONDecodeError:
            pass
        return ""

    @staticmethod
    def _fallback(mode: str, book_title: str, content: str) -> str:
        pool = FALLBACK_FIRST.get(mode, FALLBACK_FIRST["resonance"])
        seed = hash(book_title + content[:50] + mode)
        return pool[seed % len(pool)]
