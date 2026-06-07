"""预言输出清洗与质量门（移植自 lib/utils/prophecy_normalizer.dart）。"""

from __future__ import annotations

import re

MAX_CHARS = 45
MIN_CHARS = 12

_CHAT_ML_TOKENS = re.compile(
    r"<\|im_start\|>(?:system|user|assistant)?|<\|im_end\|>|<\|endoftext\|>"
)
_ASSISTANT_PREFIX = re.compile(r"^assistant\s*[\n:：]*")
_FORBIDDEN_PREFIXES = re.compile(
    r"^(预言[：:]\s*|好的[，,]\s*|作为预言家[，,]\s*|我是[^，,。]*[，,]\s*|写一条[^，。]*[，,]\s*)"
)
_HAS_CHINESE = re.compile(r"[\u4e00-\u9fff]")
_HAS_ENGLISH = re.compile(r"[a-zA-Z]")
_HAS_EMOJI = re.compile(
    r"[\U0001F300-\U0001F9FF\u2600-\u26FF\u2700-\u27BF]"
)
_PROMPT_ECHO = re.compile(
    r"上一句[是为：:]|上一句预言|当前传感器|当前状态|传感器数据|写一条|写一句|必须写|编号\d|"
    r"^示例[：:]|^参考[：:]|^数据[：:]|预言家|根据.*数据写|只输出|禁止|要求[：:]"
)
_PROMPT_LEAK_MARKERS = [
    "<|im_start|>",
    "<|im_end|>",
    "传感器数据",
    "当前传感器",
    "当前状态",
    "参考格式",
    "请根据",
    "写一条",
    "写一句",
    "示例",
    "参考：",
    "数据：",
    "上一句",
    "编号",
    "预言：",
    "user\n",
    "assistant\n",
    "system\n",
]
_STRIP_META_PATTERNS = [
    re.compile(r"^上一句[是为：:]\s*"),
    re.compile(r"^当前状态[是为：:]\s*"),
    re.compile(r"^当前传感器[：:]\s*"),
    re.compile(r"^数据[：:]\s*"),
    re.compile(r"^参考[：:]\s*"),
]
_PUNCT_END = re.compile(r"[。！？]")
_PUNCT_TRUNC = re.compile(r"[，。！？、；]")


def is_prompt_echo(text: str) -> bool:
    t = text.strip()
    if not t:
        return True
    if _PROMPT_ECHO.search(t):
        return True
    return t.startswith("数据：") or t.startswith("参考：")


def normalize_prophecy(raw: str) -> str:
    text = raw.strip()
    if not text:
        return ""

    text = _CHAT_ML_TOKENS.sub("", text).strip()
    text = _ASSISTANT_PREFIX.sub("", text).strip()
    text = re.sub(r"[\r\n]+", "，", text)
    text = re.sub(r"\s{2,}", "", text)

    for marker in _PROMPT_LEAK_MARKERS:
        if not marker:
            continue
        idx = text.find(marker)
        if idx > 0:
            text = text[:idx].strip()

    text = re.sub(r'^["「『]|["」』]$', "", text)
    while _FORBIDDEN_PREFIXES.match(text):
        text = _FORBIDDEN_PREFIXES.sub("", text, count=1).strip()

    for pattern in _STRIP_META_PATTERNS:
        if pattern.match(text):
            text = pattern.sub("", text, count=1).strip()

    text = _first_sentence(text)
    text = re.sub(r"[，、；]+$", "", text)
    if not text:
        return ""

    if len(text) <= MAX_CHARS:
        return text
    return _truncate_at_punctuation(text, MAX_CHARS)


def _first_sentence(text: str) -> str:
    match = _PUNCT_END.search(text)
    if match:
        candidate = text[: match.end()].strip()
        if len(candidate) >= MIN_CHARS:
            return candidate
    return text.strip()


def _truncate_at_punctuation(text: str, max_len: int) -> str:
    best = max_len
    for i, ch in enumerate(text[:max_len]):
        if _PUNCT_TRUNC.match(ch):
            best = i + 1
    if best < MIN_CHARS:
        best = max_len
    return text[: min(best, len(text))]


def is_soft_acceptable_prophecy(text: str) -> bool:
    if not text or is_prompt_echo(text):
        return False
    if len(text) < MIN_CHARS or len(text) > MAX_CHARS:
        return False
    if not _HAS_CHINESE.search(text):
        return False
    if _HAS_ENGLISH.search(text):
        return False
    if _HAS_EMOJI.search(text):
        return False
    if _FORBIDDEN_PREFIXES.match(text):
        return False
    return True
