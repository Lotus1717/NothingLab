"""阅读模式工具函数测试。"""

from app.models.reading_mode import (
    DEFAULT_MODE,
    depth_label,
    resolve_mode,
)


def test_resolve_mode_explicit():
    assert resolve_mode("comprehension") == "comprehension"
    assert resolve_mode("dialectic") == "dialectic"


def test_resolve_mode_auto_low_confidence():
    assert resolve_mode("auto", "comprehension", 0.69) == DEFAULT_MODE


def test_resolve_mode_auto_high_confidence():
    assert resolve_mode("auto", "application", 0.85) == "application"


def test_depth_label_resonance():
    assert depth_label("resonance", 1) == "触动"
    assert depth_label("resonance", 3) == "细节"


def test_depth_label_comprehension():
    assert depth_label("comprehension", 2) == "联系"
