"""预言生成编排：配额检查、DeepSeek 调用、质量门。"""

from __future__ import annotations

from app.models.sensor import SensorPayload
from app.services.deepseek_client import DeepSeekClient, RETRY_TEMPERATURE
from app.services.prophecy_normalizer import (
    is_soft_acceptable_prophecy,
    normalize_prophecy,
)


async def generate_with_quality_gate(
    client: DeepSeekClient,
    sensor: SensorPayload,
    *,
    nonce: int,
) -> str:
    soft_candidate = ""

    raw = await client.generate(sensor, nonce=nonce)
    text = normalize_prophecy(raw or "")
    if text and is_soft_acceptable_prophecy(text):
        return text
    if text:
        soft_candidate = text

    raw = await client.generate(
        sensor, nonce=nonce + 1000, temperature=RETRY_TEMPERATURE
    )
    text = normalize_prophecy(raw or "")
    if text and is_soft_acceptable_prophecy(text):
        return text

    return soft_candidate
