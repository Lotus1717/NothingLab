"""微信读书非官方 API 客户端。"""

from __future__ import annotations

import json
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
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Referer": "https://weread.qq.com/web/shelf",
    "Origin": "https://weread.qq.com",
}

# i.weread.qq.com 已普遍返回 -2012；Web 端接口仍可用
_WEB_SHELF_SYNC = "https://weread.qq.com/web/shelf/sync"
_WEB_SHELF_BOOK_IDS = "https://weread.qq.com/web/shelf/bookIds"
_WEB_SHELF_PAGE = "https://weread.qq.com/web/shelf"
_API_USER_NOTEBOOK = "https://weread.qq.com/api/user/notebook"
_API_BOOK_INFO = "https://weread.qq.com/api/book/info"
_WEB_BEST_BOOKMARKS = "https://weread.qq.com/web/book/bestbookmarks"

_AUTH_ERR_CODES = {-2012, -2041, -2010, 401, 403}


class WeReadError(Exception):
    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)


def _normalize_cookie_raw(cookie: str) -> str:
    raw = cookie.strip()
    if raw.lower().startswith("cookie:"):
        raw = raw[7:].strip()
    raw = re.sub(r"[\r\n\t]+", "; ", raw)
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
    preferred = ("wr_vid", "wr_skey", "wr_rt", "wr_fp", "wr_gid")
    keys = [k for k in preferred if k in cookies]
    keys.extend(sorted(k for k in cookies if k not in preferred))
    return "; ".join(f"{k}={cookies[k]}" for k in keys)


def _weread_error_message(resp: httpx.Response) -> str:
    try:
        data = resp.json()
        if isinstance(data, dict):
            errmsg = str(
                data.get("errmsg") or data.get("errMsg") or data.get("message") or ""
            ).strip()
            if errmsg:
                return f"{errmsg}（HTTP {resp.status_code}）"
    except Exception:
        pass
    return f"HTTP {resp.status_code}"


def _raise_if_json_error(data: Any) -> None:
    if not isinstance(data, dict):
        return
    for key in ("errcode", "errCode"):
        if key not in data:
            continue
        try:
            code = int(data[key])
        except (TypeError, ValueError):
            continue
        if code == 0:
            return
        msg = str(data.get("errmsg") or data.get("errMsg") or "").strip()
        if code in _AUTH_ERR_CODES or "登录" in msg or "过期" in msg:
            raise WeReadError(
                "Cookie 已过期或无效。请在电脑浏览器重新登录 weread.qq.com，"
                "打开书架任意一本书后，从开发者工具复制完整 Cookie（含 wr_rt）"
            )
        if msg:
            raise WeReadError(f"微信读书返回：{msg}（{code}）")
        raise WeReadError(f"微信读书返回错误码 {code}")


def _extract_books(payload: dict[str, Any]) -> list[dict[str, str]]:
    books: list[dict[str, str]] = []
    seen: set[str] = set()

    def add_book(raw: dict[str, Any]) -> None:
        info = raw.get("bookInfo") if isinstance(raw.get("bookInfo"), dict) else raw
        if isinstance(raw.get("book"), dict):
            nested = raw["book"]
            info = {**nested, **info} if isinstance(info, dict) else nested

        book_id = str(
            info.get("bookId")
            or raw.get("bookId")
            or raw.get("book_id")
            or ""
        ).strip()
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

    for key in ("books", "bookItems", "recentBooks", "finishReadBooks", "updated"):
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


def _extract_books_from_html(html: str) -> list[dict[str, str]]:
    books: list[dict[str, str]] = []
    seen: set[str] = set()

    patterns = [
        r"window\.__INITIAL_STATE__\s*=\s*(\{.*?\})\s*;",
        r"window\.INITIAL_STATE\s*=\s*(\{.*?\})\s*;",
    ]
    for pattern in patterns:
        match = re.search(pattern, html, re.DOTALL)
        if not match:
            continue
        try:
            payload = json.loads(match.group(1))
        except json.JSONDecodeError:
            continue
        extracted = _extract_books(payload)
        for book in extracted:
            if book["book_id"] not in seen:
                seen.add(book["book_id"])
                books.append(book)

    if books:
        return books

    for book_id, title in re.findall(
        r'"bookId"\s*:\s*"?(\d+)"?.*?"title"\s*:\s*"([^"\\]+)"',
        html,
    ):
        if book_id in seen:
            continue
        seen.add(book_id)
        books.append(
            {
                "book_id": book_id,
                "title": title,
                "author": "",
                "cover": "",
            }
        )
    return books


async def _fetch_book_infos(
    client: httpx.AsyncClient, headers: dict[str, str], book_ids: list[str]
) -> list[dict[str, str]]:
    books: list[dict[str, str]] = []
    for book_id in book_ids[:80]:
        resp = await client.get(
            _API_BOOK_INFO,
            headers={**headers, "Referer": "https://weread.qq.com/web/shelf"},
            params={"bookId": book_id},
        )
        if resp.status_code != 200:
            continue
        try:
            data = resp.json()
        except Exception:
            continue
        _raise_if_json_error(data)
        extracted = _extract_books(data)
        if extracted:
            books.append(extracted[0])
    return books


async def _try_web_shelf_sync(
    client: httpx.AsyncClient, headers: dict[str, str]
) -> list[dict[str, str]]:
    resp = await client.get(_WEB_SHELF_SYNC, headers=headers)
    if resp.status_code in (401, 403):
        raise WeReadError(
            f"同步失败：{_weread_error_message(resp)}。"
            "Cookie 可能已过期，请重新登录 weread.qq.com"
        )
    if resp.status_code != 200:
        raise WeReadError(f"书架同步接口异常：{_weread_error_message(resp)}")

    data = resp.json()
    _raise_if_json_error(data)
    books = _extract_books(data)
    if books:
        return books
    return []


async def _try_api_notebook(
    client: httpx.AsyncClient, headers: dict[str, str]
) -> list[dict[str, str]]:
    resp = await client.get(
        _API_USER_NOTEBOOK,
        headers={**headers, "Referer": "https://weread.qq.com/web/shelf"},
    )
    if resp.status_code in (401, 403):
        raise WeReadError(
            f"笔记本接口认证失败：{_weread_error_message(resp)}。"
            "请重新登录 weread.qq.com 后复制完整 Cookie"
        )
    if resp.status_code != 200:
        return []

    data = resp.json()
    _raise_if_json_error(data)
    return _extract_books(data)


async def _try_web_shelf_book_ids(
    client: httpx.AsyncClient, headers: dict[str, str]
) -> list[dict[str, str]]:
    resp = await client.get(_WEB_SHELF_BOOK_IDS, headers=headers)
    if resp.status_code != 200:
        return []

    try:
        data = resp.json()
    except Exception:
        return []

    _raise_if_json_error(data)
    book_ids: list[str] = []
    if isinstance(data, dict):
        raw_ids = data.get("bookIds") or data.get("books") or []
        if isinstance(raw_ids, list):
            for item in raw_ids:
                if isinstance(item, str) and item.isdigit():
                    book_ids.append(item)
                elif isinstance(item, dict):
                    bid = str(item.get("bookId") or "").strip()
                    if bid.isdigit():
                        book_ids.append(bid)
    return await _fetch_book_infos(client, headers, book_ids)


async def _try_web_shelf_html(
    client: httpx.AsyncClient, headers: dict[str, str]
) -> list[dict[str, str]]:
    resp = await client.get(
        _WEB_SHELF_PAGE,
        headers={**headers, "Accept": "text/html,application/json,*/*"},
    )
    if resp.status_code != 200:
        return []
    return _extract_books_from_html(resp.text)


async def sync_shelf(cookie: str) -> list[dict[str, str]]:
    cookies = parse_cookie_string(cookie)
    headers = {**_HEADERS, "Cookie": _cookie_header(cookies)}

    async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
        errors: list[str] = []
        for fetcher in (
            _try_web_shelf_sync,
            _try_api_notebook,
            _try_web_shelf_book_ids,
            _try_web_shelf_html,
        ):
            try:
                books = await fetcher(client, headers)
                if books:
                    return sorted(books, key=lambda b: b["title"])
            except WeReadError as exc:
                errors.append(exc.message)
                if "过期" in exc.message or "无效" in exc.message:
                    raise

        if errors:
            raise WeReadError(errors[-1])
        raise WeReadError(
            "书架为空或无法解析。请确认微信读书账号里已有书，"
            "并在 weread.qq.com 登录后打开书架任意一本书，再重新复制 Cookie"
        )


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
