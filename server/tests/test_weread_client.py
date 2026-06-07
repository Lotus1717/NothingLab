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
