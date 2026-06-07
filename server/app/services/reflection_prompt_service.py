"""AI 辅助提问 — 引导写感想，不代写。"""

from __future__ import annotations

import json
import re

import httpx

from app.config import Settings

_PROMPT_SYSTEM = """你是一位温和的阅读陪伴者。用户刚读完一页书摘，你需要提一个简短、开放的问题，引导 TA 写一句感想。

要求：
- 只输出一个问题，15-30 字
- 不要替用户写感想
- 不要总结书摘内容
- 问题要有温度，像朋友聊天
- 直接输出问题文本，不要 JSON、不要引号"""


class ReflectionPromptService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def generate(self, book_title: str, content: str) -> str:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            return self._fallback(book_title, content)

        url = f"{self._settings.deepseek_api_base}/chat/completions"
        user_msg = (
            f"书名：《{book_title}》\n"
            f"今日读到的内容：{content[:600]}\n"
            "请提一个问题，引导用户写一句感想。"
        )
        payload = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": _PROMPT_SYSTEM},
                {"role": "user", "content": user_msg},
            ],
            "temperature": 0.9,
            "max_tokens": 80,
            "stream": False,
        }
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        }

        async with httpx.AsyncClient(
            timeout=self._settings.deepseek_timeout_seconds
        ) as client:
            response = await client.post(url, json=payload, headers=headers)

        if response.status_code != 200:
            return self._fallback(book_title, content)

        decoded = response.json()
        choices = decoded.get("choices") or []
        if not choices:
            return self._fallback(book_title, content)

        raw = choices[0].get("message", {}).get("content", "").strip()
        raw = re.sub(r"^[「『\"']|[」』\"']$", "", raw)
        return raw if raw else self._fallback(book_title, content)

    @staticmethod
    def _fallback(book_title: str, content: str) -> str:
        _pool = [
            "这段里，哪一句话最打动你？",
            "读到这里，你想到了生活中的什么事？",
            "如果用一句话回应这段文字，你会说什么？",
            f"《{book_title}》的这一段，让你想起了什么？",
        ]
        seed = hash(book_title + content[:50])
        return _pool[seed % len(_pool)]
