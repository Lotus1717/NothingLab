from app.services.daily_page_service import (
    _normalize_book_title,
    _sanitize_source_note,
    _titles_match,
)


def test_normalize_book_title_strips_guillemets_and_spaces():
    assert _normalize_book_title("《三体》") == "三体"
    assert _normalize_book_title(" 活 着 ") == "活着"


def test_titles_match_exact_and_subtitle_variants():
    assert _titles_match("三体", "三体")
    assert _titles_match("三体", "《三体》")
    assert _titles_match("三体：地球往事", "三体")
    assert not _titles_match("三体", "活着")
    assert not _titles_match("三体", "")


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


def test_sanitize_source_note_replaces_meta_summaries():
    assert (
        _sanitize_source_note("全书核心思想提炼，涉及黑暗森林法则")
        == "节选"
    )
