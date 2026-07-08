"""AI 多轮深度思考 — 按阅读模式引导追问。"""

from __future__ import annotations

import json
import re

import httpx

from app.config import Settings
from app.models.reading_mode import depth_label, resolve_mode
from app.services.reflection_prompt_builder import (
    build_followup_system,
    build_followup_user,
    build_mode_detection_user,
    FALLBACK_FIRST,
    MODE_DETECTION_SYSTEM,
)


class DeepReflectionService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def continue_reflection(
        self,
        *,
        book_title: str,
        author: str,
        content: str,
        reading_mode: str,
        history: list[dict[str, str]],
    ) -> dict[str, object]:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            raise RuntimeError("DeepSeek API 未配置")

        resolved = reading_mode
        if reading_mode == "auto":
            detected = await self._detect_mode(book_title, author, content)
            resolved = resolve_mode(
                "auto",
                detected.get("reading_mode"),
                float(detected.get("confidence", 0)),
            )

        depth_level = self._estimate_depth(resolved, history)
        label = depth_label(resolved, depth_level)

        system = build_followup_system(resolved)
        user_msg = build_followup_user(
            resolved, book_title, content, depth_level, label, history
        )

        raw = await self._call_deepseek(system, user_msg, temperature=0.85, max_tokens=200)
        parsed = self._parse_followup(raw, resolved, depth_level, label)
        parsed["reading_mode"] = resolved
        return parsed

    async def detect_mode(
        self, book_title: str, author: str, content: str
    ) -> dict[str, object]:
        return await self._detect_mode(book_title, author, content)

    async def _detect_mode(
        self, book_title: str, author: str, content: str
    ) -> dict[str, object]:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            return {
                "reading_mode": "resonance",
                "confidence": 0.0,
                "reason": "no api key",
            }

        user_msg = build_mode_detection_user(book_title, author, content)
        raw = await self._call_deepseek(
            MODE_DETECTION_SYSTEM, user_msg, temperature=0.3, max_tokens=120
        )
        return self._parse_detection(raw)

    async def _call_deepseek(
        self,
        system: str,
        user: str,
        *,
        temperature: float,
        max_tokens: int,
    ) -> str:
        url = f"{self._settings.deepseek_api_base}/chat/completions"
        payload = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
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
            raise RuntimeError(f"DeepSeek HTTP {response.status_code}")

        decoded = response.json()
        choices = decoded.get("choices") or []
        if not choices:
            raise RuntimeError("DeepSeek 返回为空")

        content = choices[0].get("message", {}).get("content", "")
        if not isinstance(content, str) or not content.strip():
            raise RuntimeError("DeepSeek 内容为空")
        return content.strip()

    @staticmethod
    def _estimate_depth(mode: str, history: list[dict[str, str]]) -> int:
        user_turns = sum(1 for h in history if h.get("role") == "user")
        return max(1, user_turns + 1)

    def _parse_followup(
        self,
        raw: str,
        mode: str,
        default_level: int,
        default_label: str,
    ) -> dict[str, object]:
        parsed = self._extract_json(raw)
        question = str(parsed.get("question", "")).strip()
        if not question:
            question = self._fallback_followup(mode, default_level)

        question = re.sub(r"^[「『\"']|[」』\"']$", "", question)
        depth_level = int(parsed.get("depth_level", default_level))
        label = str(parsed.get("depth_label", default_label)) or depth_label(
            mode, depth_level
        )
        can_conclude = bool(parsed.get("can_conclude", False))

        return {
            "question": question,
            "depth_level": depth_level,
            "depth_label": label,
            "can_conclude": can_conclude,
        }

    @staticmethod
    def _parse_detection(raw: str) -> dict[str, object]:
        parsed = DeepReflectionService._extract_json(raw)
        mode = str(parsed.get("reading_mode", "resonance"))
        if mode not in ("resonance", "comprehension", "dialectic", "application"):
            mode = "resonance"
        confidence = float(parsed.get("confidence", 0.5))
        confidence = max(0.0, min(1.0, confidence))
        reason = str(parsed.get("reason", ""))
        return {
            "reading_mode": mode,
            "confidence": confidence,
            "reason": reason,
        }

    @staticmethod
    def _extract_json(raw: str) -> dict[str, object]:
        text = raw.strip()
        fence = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
        if fence:
            text = fence.group(1).strip()
        try:
            data = json.loads(text)
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            pass
        return {}

    @staticmethod
    def _fallback_followup(mode: str, depth_level: int) -> str:
        pool = FALLBACK_FIRST.get(mode, FALLBACK_FIRST["resonance"])
        return pool[(depth_level - 1) % len(pool)]
