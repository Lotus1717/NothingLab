"""微信读书非官方 API 客户端。"""

from __future__ import annotations

import re
from http.cookies import SimpleCookie
from typing import Any

import httpx

_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
_HEADERS = {
    "User-Agent": _USER_AGENT,
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://weread.qq.com/web/shelf",
    "Origin": "https://weread.qq.com",
}

# i.weread.qq.com 已普遍返回 -2012；Web 端接口仍可用
_WEB_SHELF_SYNC = "https://weread.qq.com/web/shelf/sync"
_WEB_BEST_BOOKMARKS = "https://weread.qq.com/web/book/bestbookmarks"


class WeReadError(Exception):
    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)


def _normalize_cookie_raw(cookie: str) -> str:
    raw = cookie.strip()
    if raw.lower().startswith("cookie:"):
        raw = raw[7:].strip()
    # 换行 / Tab 分隔（DevTools 多行复制）
    raw = re.sub(r"[\r\n\t]+", "; ", raw)
    # 合并多余分号
    raw = re.sub(r";\s*;", "; ", raw)
    return raw.strip(" ;")


def parse_cookie_string(cookie: str) -> dict[str, str]:
    raw = _normalize_cookie_raw(cookie)
    if not raw:
        raise WeReadError("Cookie 不能为空")

    cookies: dict[str, str] = {}
    for part in re.split(r"[;\s]+", raw):
        part = part.strip()
        if not part or "=" not in part:
            continue
        key, value = part.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            cookies[key] = value

    # SimpleCookie 兜底（处理带引号/特殊字符的值）
    if not cookies and "=" in raw:
        cookie_obj = SimpleCookie()
        cookie_obj.load(raw)
        for key, morsel in cookie_obj.items():
            cookies[key] = morsel.value

    if not cookies.get("wr_vid"):
        raise WeReadError(
            "Cookie 中缺少 wr_vid。请从 weread.qq.com 复制完整 Cookie，"
            "格式示例：wr_vid=123456; wr_skey=abcdef"
        )
    if not cookies.get("wr_skey"):
        raise WeReadError(
            "Cookie 中缺少 wr_skey。请同时复制 wr_vid 和 wr_skey 两项，"
            "用英文分号连接"
        )
    return cookies


def _cookie_header(cookies: dict[str, str]) -> str:
    """构建 Web API 所需的 Cookie 头，保留全部已解析字段。"""
    preferred = ("wr_vid", "wr_skey", "wr_rt")
    keys = [k for k in preferred if k in cookies]
    keys.extend(sorted(k for k in cookies if k not in preferred))
    return "; ".join(f"{k}={cookies[k]}" for k in keys)


def _weread_error_message(resp: httpx.Response) -> str:
    try:
        data = resp.json()
        if isinstance(data, dict):
            errmsg = str(data.get("errmsg") or data.get("message") or "").strip()
            if errmsg:
                return f"{errmsg}（HTTP {resp.status_code}）"
    except Exception:
        pass
    return f"HTTP {resp.status_code}"


def _extract_books(payload: dict[str, Any]) -> list[dict[str, str]]:
    books: list[dict[str, str]] = []
    seen: set[str] = set()

    def add_book(raw: dict[str, Any]) -> None:
        info = raw.get("bookInfo") if isinstance(raw.get("bookInfo"), dict) else raw
        book_id = str(info.get("bookId") or raw.get("bookId") or "").strip()
        if not book_id or not book_id.isdigit() or book_id in seen:
            return
        title = str(info.get("title") or raw.get("title") or "").strip()
        if not title:
            return
        seen.add(book_id)
        books.append(
            {
                "book_id": book_id,
                "title": title,
                "author": str(info.get("author") or raw.get("author") or "").strip(),
                "cover": str(info.get("cover") or raw.get("cover") or "").strip(),
            }
        )

    for key in ("books", "bookItems", "recentBooks", "finishReadBooks"):
        items = payload.get(key)
        if isinstance(items, list):
            for item in items:
                if isinstance(item, dict):
                    add_book(item)

    for shelf in payload.get("shelf", []):
        if isinstance(shelf, dict):
            for item in shelf.get("books", []):
                if isinstance(item, dict):
                    add_book(item)

    return books


async def sync_shelf(cookie: str) -> list[dict[str, str]]:
    cookies = parse_cookie_string(cookie)
    headers = {**_HEADERS, "Cookie": _cookie_header(cookies)}

    async with httpx.AsyncClient(timeout=30.0, headers=headers) as client:
        sync_resp = await client.get(_WEB_SHELF_SYNC)
        if sync_resp.status_code == 200:
            books = _extract_books(sync_resp.json())
            if books:
                return sorted(books, key=lambda b: b["title"])
            raise WeReadError("书架为空，请确认微信读书账号里已有书籍")

        detail = _weread_error_message(sync_resp)
        if sync_resp.status_code in (401, 403):
            raise WeReadError(
                f"同步失败：{detail}。Cookie 可能已过期，请重新登录 weread.qq.com 后复制 wr_vid 与 wr_skey"
            )
        raise WeReadError(f"同步失败：{detail}，请检查 Cookie 是否完整")


_MIN_MARK_LEN = 200
_MAX_MARK_LEN = 800


def _normalize_mark_text(text: str) -> str:
    return re.sub(r"\s+", " ", str(text)).strip()


def _pick_mark_content(marks: list[str], seed: int) -> str:
    """优先 200-800 字划线；过短则拼接相邻划线或选更长的。"""
    if not marks:
        return ""

    preferred = [m for m in marks if _MIN_MARK_LEN <= len(m) <= _MAX_MARK_LEN]
    if preferred:
        return preferred[seed % len(preferred)]

    combined: list[str] = []
    for i in range(len(marks)):
        chunk = marks[i]
        for j in range(i + 1, len(marks)):
            chunk = f"{chunk}\n\n{marks[j]}"
            if len(chunk) > _MAX_MARK_LEN:
                break
            if len(chunk) >= _MIN_MARK_LEN:
                combined.append(chunk)

    if combined:
        return combined[seed % len(combined)]

    return max(marks, key=len)


async def fetch_best_bookmark(
    cookie: str, book_id: str, *, seed: int = 0
) -> dict[str, str] | None:
    cookies = parse_cookie_string(cookie)
    headers = {
        **_HEADERS,
        "Cookie": _cookie_header(cookies),
        "Referer": "https://weread.qq.com/web/reader",
    }
    async with httpx.AsyncClient(timeout=30.0, headers=headers) as client:
        resp = await client.get(
            _WEB_BEST_BOOKMARKS,
            params={"bookId": book_id},
        )
        if resp.status_code != 200:
            return None

        data = resp.json()
        best = data.get("bestBookMarks")
        if isinstance(best, dict):
            items = best.get("items") or best.get("bookmarks") or []
        else:
            items = data.get("items") or data.get("bookmarks") or []
        marks: list[str] = []
        chapters: list[str] = []
        for item in items:
            if not isinstance(item, dict):
                continue
            text = _normalize_mark_text(
                item.get("markText")
                or item.get("abstract")
                or item.get("content")
                or ""
            )
            if len(text) >= 12:
                marks.append(text)
                chapters.append(
                    str(item.get("chapterName") or "").strip()
                )

        if not marks:
            return None

        content = _pick_mark_content(marks, seed)
        idx = seed % len(marks)
        chapter = chapters[idx] if idx < len(chapters) else ""

        return {"content": content, "source_note": chapter or "热门划线"}
