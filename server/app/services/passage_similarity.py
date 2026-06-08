"""书摘段落相似度 — 换页去重。"""

from __future__ import annotations

import re
from difflib import SequenceMatcher

OVERLAP_THRESHOLD = 0.52


def normalize_compare_text(text: str) -> str:
    return re.sub(r"\s+", "", str(text)).strip()


def overlap_ratio(left: str, right: str) -> float:
    a = normalize_compare_text(left)[:1200]
    b = normalize_compare_text(right)[:1200]
    if not a or not b:
        return 0.0
    if a in b or b in a:
        return 1.0
    return SequenceMatcher(None, a, b).ratio()


def is_too_similar(content: str, exclude_contents: list[str]) -> bool:
    for prior in exclude_contents:
        prior = prior.strip()
        if not prior:
            continue
        if overlap_ratio(content, prior) >= OVERLAP_THRESHOLD:
            return True
    return False
