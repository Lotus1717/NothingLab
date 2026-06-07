"""weread_client Cookie 解析测试。"""

from __future__ import annotations

import pytest

from app.services.weread_client import WeReadError, parse_cookie_string


def test_parse_cookie_semicolon_format() -> None:
    cookies = parse_cookie_string("wr_vid=123456; wr_skey=abcDEF")
    assert cookies["wr_vid"] == "123456"
    assert cookies["wr_skey"] == "abcDEF"


def test_parse_cookie_newline_format() -> None:
    cookies = parse_cookie_string("wr_vid=123456\nwr_skey=abcDEF")
    assert cookies["wr_vid"] == "123456"
    assert cookies["wr_skey"] == "abcDEF"


def test_parse_cookie_with_cookie_prefix() -> None:
    cookies = parse_cookie_string("Cookie: wr_vid=1; wr_skey=2")
    assert cookies["wr_vid"] == "1"
    assert cookies["wr_skey"] == "2"


def test_parse_cookie_missing_wr_skey() -> None:
    with pytest.raises(WeReadError, match="wr_skey"):
        parse_cookie_string("wr_vid=123456")


def test_parse_cookie_missing_wr_vid() -> None:
    with pytest.raises(WeReadError, match="wr_vid"):
        parse_cookie_string("wr_skey=abc")


def test_cookie_header_minimal() -> None:
    from app.services.weread_client import _cookie_header

    header = _cookie_header({"wr_vid": "123", "wr_skey": "abc"})
    assert header == "wr_vid=123; wr_skey=abc"


def test_cookie_header_with_wr_rt() -> None:
    from app.services.weread_client import _cookie_header

    header = _cookie_header(
        {"wr_vid": "123", "wr_skey": "abc", "wr_rt": "web%40token"}
    )
    assert header == "wr_vid=123; wr_skey=abc; wr_rt=web%40token"


def test_cookie_header_preserves_extra_keys() -> None:
    from app.services.weread_client import _cookie_header

    header = _cookie_header(
        {
            "wr_fp": "fpval",
            "wr_vid": "123",
            "wr_skey": "abc",
            "wr_rt": "rtval",
        }
    )
    assert header == "wr_vid=123; wr_skey=abc; wr_rt=rtval; wr_fp=fpval"


def test_parse_cookie_with_wr_rt() -> None:
    cookies = parse_cookie_string(
        "wr_vid=1; wr_skey=2; wr_rt=token; wr_fp=x"
    )
    assert cookies["wr_rt"] == "token"
    assert cookies["wr_fp"] == "x"


def test_extract_books_from_notebook_shape() -> None:
    from app.services.weread_client import _extract_books

    payload = {
        "books": [
            {
                "bookId": "12345",
                "title": "测试书",
                "author": "作者甲",
                "cover": "https://example.com/cover.jpg",
            }
        ]
    }
    books = _extract_books(payload)
    assert len(books) == 1
    assert books[0]["book_id"] == "12345"
    assert books[0]["title"] == "测试书"


def test_extract_books_from_html_initial_state() -> None:
    from app.services.weread_client import _extract_books_from_html

    html = """
    <script>
    window.__INITIAL_STATE__ = {"books":[{"bookId":"999","title":"HTML书","author":"乙"}]};
    </script>
    """
    books = _extract_books_from_html(html)
    assert len(books) == 1
    assert books[0]["book_id"] == "999"
    assert books[0]["title"] == "HTML书"


def test_raise_if_json_error_auth_code() -> None:
    from app.services.weread_client import WeReadError, _raise_if_json_error

    with pytest.raises(WeReadError, match="过期"):
        _raise_if_json_error({"errcode": -2012, "errmsg": "登录超时"})
