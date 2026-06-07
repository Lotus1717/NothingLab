"""预言 prompt 构建（移植自 lib/utils/prophecy_prompt_builder.dart）。"""

from __future__ import annotations

from dataclasses import dataclass

from app.models.sensor import SensorPayload

_FEW_SHOT_EXAMPLES = [
    "电量72%时，你的拇指滑屏速度会比平时快1.2倍",
    "你接下来的三分钟内会突然想起一件无关紧要的小事",
    "今天你会在电梯里和陌生人交换一个意味深长的眼神",
]

_SYSTEM_PROMPT = """你是废话预言家。写一句中文废话预言。
要求：32-42字；第二人称「你」；冷幽默荒诞；可不提及传感器数据。
禁止：解释、题面复述、出现「上一句」「传感器」「当前状态」「写一条」等词。
只输出预言正文一行。"""


@dataclass(frozen=True)
class MlxChatPrompt:
    system: str
    user: str


def _sensor_facts(sensor: SensorPayload) -> str:
    battery = sensor.battery if sensor.battery is not None else 50
    motion = "移动" if sensor.is_moving else "静止"
    light = ""
    if sensor.is_real_ambient_light or sensor.is_estimated_ambient_light:
        light = f"，光线{sensor.ambient_light}勒克斯"
    return (
        f"电量{battery}%，亮度{sensor.brightness}%，音量{sensor.volume}%，"
        f"步数{sensor.steps}，{motion}，{sensor.day_phase}{light}"
    )


def build_prompt(sensor: SensorPayload, *, nonce: int = 0) -> str:
    salt = nonce
    example = _FEW_SHOT_EXAMPLES[salt % len(_FEW_SHOT_EXAMPLES)]
    return (
        "写一条中文废话预言：第二人称「你」，32-42字，冷幽默荒诞，只输出预言正文。\n\n"
        f"可参考（不必写入正文）数据：{_sensor_facts(sensor)}\n"
        f"风格参考：{example}"
    )


def build_mlx_chat(sensor: SensorPayload, *, nonce: int = 0) -> MlxChatPrompt:
    salt = nonce
    example = _FEW_SHOT_EXAMPLES[salt % len(_FEW_SHOT_EXAMPLES)]
    user = (
        f"可参考数据：{_sensor_facts(sensor)}\n"
        f"风格参考：{example}"
    )
    return MlxChatPrompt(system=_SYSTEM_PROMPT, user=user)
