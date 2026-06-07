"""每日一页服务 — DeepSeek 真实书摘，无 mock 兜底。"""

from __future__ import annotations

import json
import re
from datetime import date

import httpx

from app.config import Settings
from app.services.weread_client import fetch_best_bookmark

PAGE_MAX_TOKENS = 1400
PAGE_TEMPERATURE = 0.85

_SOURCE_NOTE_EXAMPLE = "第三章、序章、第二部 · 第一节"
_SOURCE_NOTE_RULE = (
    f"- source_note 必须是中文可读的章节名（如「{_SOURCE_NOTE_EXAMPLE}」），"
    "禁止缩写、代码或英文编号（如 20d-30c、ch3、Part 2）；"
    "若无法确定具体章节，写「节选」或「摘录」，勿编造神秘代号"
)
_SOURCE_NOTE_GARBLED = re.compile(
    r"^\d+[a-zA-Z]-\d+[a-zA-Z]$"
    r"|^ch\d+$"
    r"|^part\s*\d+$"
    r"|^chapter\s*\d+$"
    r"|^p\d+$",
    re.IGNORECASE,
)


def _sanitize_source_note(note: str) -> str:
    cleaned = note.strip()
    if not cleaned:
        return "节选"
    if _SOURCE_NOTE_GARBLED.fullmatch(cleaned):
        return "节选"
    if not re.search(r"[\u4e00-\u9fff]", cleaned) and re.fullmatch(
        r"[\w\-\.]+", cleaned
    ):
        return "节选"
    return cleaned


_SYSTEM_PROMPT_SPECIFIC = f"""你是一个博学的荐书人。用户指定了一本书，请从该书中推荐一段真实、有启发的摘录。

输出严格按以下 JSON 格式，不要包含其他内容：
{{
  "book_title": "书名",
  "author": "作者名",
  "content": "摘录正文（400-650字，2-3段，段间空行）",
  "source_note": "出处章节（中文可读名，如「{_SOURCE_NOTE_EXAMPLE}」）"
}}

约束：
- 必须来自用户指定的书，不要换成别的书
- 摘录有启发性、耐读
- 书名作者与指定书目一致
- 写成完整小段落，有观点或可共鸣情境，勿写成单句金句
{_SOURCE_NOTE_RULE}"""

_SYSTEM_PROMPT_DISCOVERY = f"""你是一个博学的荐书人。请从真实存在的经典好书中推荐一段有启发的文字。

输出严格按以下 JSON 格式，不要包含其他内容：
{{
  "book_title": "书名",
  "author": "作者名",
  "content": "摘录正文（400-650字，2-3段，段间空行）",
  "source_note": "出处章节（中文可读名，如「{_SOURCE_NOTE_EXAMPLE}」）"
}}

约束：
- 书名和作者必须真实
- 每次推荐不同的书（用户可能会点击换一本）
- 涵盖文学、哲学、心理学、科普、传记等
- 摘录有启发性、耐读
- 写成完整小段落，有观点或可共鸣情境，勿写成单句金句
{_SOURCE_NOTE_RULE}"""


class DailyPageResult:
    def __init__(
        self,
        book_title: str,
        author: str,
        content: str,
        source_note: str,
        *,
        source: str = "deepseek",
    ) -> None:
        self.book_title = book_title
        self.author = author
        self.content = content
        self.source_note = source_note
        self.source = source


class DailyPageError(Exception):
    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)


class DailyPageService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._cache: dict[str, DailyPageResult] = {}

    async def generate(
        self,
        *,
        book_id: str | None = None,
        book_title: str | None = None,
        book_author: str | None = None,
        weread_cookie: str | None = None,
        nonce: int = 0,
    ) -> DailyPageResult:
        today_key = date.today().isoformat()
        cache_key = f"{today_key}:{book_id or book_title or 'discovery'}:{nonce}"
        if nonce == 0:
            cached = self._cache.get(cache_key)
            if cached is not None:
                return cached

        page: DailyPageResult | None = None

        if weread_cookie and book_id:
            try:
                seed = nonce if nonce else date.today().toordinal()
                mark = await fetch_best_bookmark(
                    weread_cookie, book_id, seed=seed
                )
                if mark:
                    page = DailyPageResult(
                        book_title=book_title or "",
                        author=book_author or "",
                        content=mark["content"],
                        source_note=mark["source_note"],
                        source="weread",
                    )
            except Exception:
                page = None

        if page is None:
            page = await self._fetch_from_deepseek(
                book_title=book_title,
                book_author=book_author,
                nonce=nonce,
            )

        if nonce == 0:
            self._cache[cache_key] = page
        return page

    async def _fetch_from_deepseek(
        self,
        *,
        book_title: str | None,
        book_author: str | None,
        nonce: int,
    ) -> DailyPageResult:
        api_key = self._settings.deepseek_api_key
        if not api_key:
            raise DailyPageError("未配置 DEEPSEEK_API_KEY")

        if book_title:
            system = _SYSTEM_PROMPT_SPECIFIC
            user_prompt = (
                f"今天日期 {date.today().isoformat()}。"
                f"请从《{book_title}》"
                f"{f'（{book_author}）' if book_author else ''}"
                f"中推荐一段精彩摘录。"
            )
        else:
            system = _SYSTEM_PROMPT_DISCOVERY
            user_prompt = (
                f"今天日期 {date.today().isoformat()}，"
                f"随机种子 {nonce}。"
                "请选一本之前没推荐过的书，推荐一段精彩摘录。"
            )

        url = f"{self._settings.deepseek_api_base}/chat/completions"
        payload = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": PAGE_TEMPERATURE,
            "max_tokens": PAGE_MAX_TOKENS,
            "stream": False,
        }
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        }

        async with httpx.AsyncClient(
            timeout=self._settings.deepseek_timeout_seconds
        ) as client:
            response = await client.post(url, json=payload, headers=headers)

        if response.status_code != 200:
            raise DailyPageError(f"DeepSeek 返回 {response.status_code}")

        decoded = response.json()
        choices = decoded.get("choices") or []
        if not choices:
            raise DailyPageError("DeepSeek 返回空 choices")

        raw = choices[0].get("message", {}).get("content", "")
        parsed = self._parse(raw)
        if book_title:
            parsed.book_title = book_title
        if book_author:
            parsed.author = book_author
        parsed.source = "deepseek"
        return parsed

    def _parse(self, raw: str) -> DailyPageResult:
        cleaned = raw.strip()
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

        try:
            data = json.loads(cleaned)
            return DailyPageResult(
                book_title=data.get("book_title", "").strip(),
                author=data.get("author", "").strip(),
                content=data.get("content", "").strip(),
                source_note=_sanitize_source_note(
                    data.get("source_note", "")
                ),
            )
        except json.JSONDecodeError:
            pass

        title_m = re.search(r"书名[：:]\s*(.+?)[\n\r]", cleaned)
        author_m = re.search(r"作者[：:]\s*(.+?)[\n\r]", cleaned)
        content_m = re.search(r"正文[：:]\s*(.+?)(?:\n|$)", cleaned)
        source_m = re.search(r"出处[：:]\s*(.+?)[\n\r]", cleaned)

        if title_m and content_m:
            return DailyPageResult(
                book_title=title_m.group(1).strip().strip("《》"),
                author=author_m.group(1).strip() if author_m else "未知",
                content=content_m.group(1).strip(),
                source_note=_sanitize_source_note(
                    source_m.group(1) if source_m else ""
                ),
            )

        raise DailyPageError("无法解析 DeepSeek 返回内容")
