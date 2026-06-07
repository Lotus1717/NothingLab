"""DeepSeek Chat Completions 客户端（移植自 lib/services/deepseek_client.dart）。"""

from __future__ import annotations

import httpx

from app.config import Settings
from app.models.sensor import SensorPayload
from app.services.prophecy_prompt_builder import build_mlx_chat

TEMPERATURE = 0.85
RETRY_TEMPERATURE = 0.7
MAX_TOKENS = 64


class DeepSeekError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class DeepSeekClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def generate(
        self,
        sensor: SensorPayload,
        *,
        nonce: int,
        temperature: float = TEMPERATURE,
    ) -> str | None:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            raise DeepSeekError("服务端未配置 DEEPSEEK_API_KEY")

        chat = build_mlx_chat(sensor, nonce=nonce)
        url = f"{self._settings.deepseek_api_base}/chat/completions"
        payload = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": chat.system},
                {"role": "user", "content": chat.user},
            ],
            "temperature": temperature,
            "max_tokens": MAX_TOKENS,
            "stream": False,
        }
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        }

        try:
            async with httpx.AsyncClient(
                timeout=self._settings.deepseek_timeout_seconds
            ) as client:
                response = await client.post(url, json=payload, headers=headers)
        except httpx.TimeoutException as exc:
            raise DeepSeekError("DeepSeek 请求超时") from exc
        except httpx.HTTPError as exc:
            raise DeepSeekError("网络异常，请检查连接后重试") from exc

        if response.status_code in (401, 403):
            raise DeepSeekError("API 密钥无效或已过期", status_code=response.status_code)
        if response.status_code < 200 or response.status_code >= 300:
            raise DeepSeekError(
                f"DeepSeek 请求失败（{response.status_code}）",
                status_code=response.status_code,
            )

        decoded = response.json()
        choices = decoded.get("choices") or []
        if not choices:
            return None

        message = choices[0].get("message") or {}
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            return None
        return content.strip()
