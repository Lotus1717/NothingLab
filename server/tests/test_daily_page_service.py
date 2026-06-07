from app.services.daily_page_service import _sanitize_source_note


def test_sanitize_source_note_replaces_garbled_codes():
    assert _sanitize_source_note("20d-30c") == "节选"
    assert _sanitize_source_note("ch3") == "节选"
    assert _sanitize_source_note("Part 2") == "节选"


def test_sanitize_source_note_keeps_chinese_chapters():
    assert _sanitize_source_note("第三章") == "第三章"
    assert _sanitize_source_note("第二部 · 第一节") == "第二部 · 第一节"
    assert _sanitize_source_note("序章") == "序章"


def test_sanitize_source_note_empty_defaults_to_excerpt():
    assert _sanitize_source_note("") == "节选"
    assert _sanitize_source_note("   ") == "节选"
