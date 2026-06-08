"""每日一页服务 — DeepSeek 真实书摘，无 mock 兜底。"""

from __future__ import annotations

import json
import re
from datetime import date

import httpx

from app.config import Settings
from app.services.weread_client import fetch_best_bookmark

PAGE_MAX_TOKENS = 1400
PAGE_TEMPERATURE_DISCOVERY = 1.1
PAGE_TEMPERATURE_SPECIFIC = 0.55
PAGE_TEMPERATURE_SPECIFIC_VARIED = 0.78
DISCOVERY_TOP_P = 0.92
DISCOVERY_PRESENCE_PENALTY = 0.45
MAX_SPECIFIC_ATTEMPTS = 2

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
_SOURCE_NOTE_META = re.compile(r"提炼|核心思想|关键章节|涉及")


def _normalize_book_title(title: str) -> str:
    cleaned = title.strip().strip("《》").strip()
    return re.sub(r"\s+", "", cleaned)


def _titles_match(expected: str, actual: str) -> bool:
    if not actual.strip():
        return False
    exp = _normalize_book_title(expected)
    act = _normalize_book_title(actual)
    if exp == act:
        return True
    return exp in act or act in exp


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
    if _SOURCE_NOTE_META.search(cleaned) and len(cleaned) > 12:
        return "节选"
    return cleaned


_SYSTEM_PROMPT_SPECIFIC = f"""你是一个博学的荐书人。用户指定了一本书，请从该书中摘录一段真实原文。

输出严格按以下 JSON 格式，不要包含其他内容：
{{
  "book_title": "书名",
  "author": "作者名",
  "content": "摘录正文（400-650字，2-3段，段间空行）",
  "source_note": "出处章节（中文可读名，如「{_SOURCE_NOTE_EXAMPLE}」）"
}}

硬性约束（违反即视为失败）：
- 摘录必须出自用户指定的那一本书，严禁换成别的书
- content 必须是该书原文或高度忠实的连续段落，禁止写成读后感、主题概括或跨书拼贴
- JSON 中的 book_title 必须与用户给出的书名完全一致（一字不差）
- author 必须与指定作者一致；若用户未给作者，填该书真实作者
- 写成完整小段落，有观点或可共鸣情境，勿写成单句金句堆砌
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
- 涵盖文学、哲学、心理学、科普、传记等，可重复推荐经典名作
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
            temperature = (
                PAGE_TEMPERATURE_SPECIFIC_VARIED
                if nonce > 0
                else PAGE_TEMPERATURE_SPECIFIC
            )
            author_hint = f"（作者：{book_author}）" if book_author else ""
            user_prompt = (
                f"今天日期 {date.today().isoformat()}。\n"
                f"指定书目：《{book_title}》{author_hint}\n"
                f"请只从《{book_title}》中摘录一段精彩原文。"
                f"响应 JSON 中 book_title 必须严格等于「{book_title}」，"
                "不要换成任何其他书。"
            )
            if nonce > 0:
                user_prompt += f"\n随机种子 {nonce}，请选择与以往不同的段落。"
            attempts = MAX_SPECIFIC_ATTEMPTS
            top_p = None
            presence_penalty = None
        else:
            system = _SYSTEM_PROMPT_DISCOVERY
            temperature = PAGE_TEMPERATURE_DISCOVERY
            top_p = DISCOVERY_TOP_P
            presence_penalty = DISCOVERY_PRESENCE_PENALTY
            user_prompt = (
                f"今天日期 {date.today().isoformat()}，"
                f"随机种子 {nonce}。"
                "请随机选一本真实好书，推荐一段精彩摘录。"
            )
            attempts = 1

        parsed: DailyPageResult | None = None
        for attempt in range(attempts):
            prompt = user_prompt
            if book_title and attempt > 0:
                wrong = parsed.book_title if parsed else ""
                prompt = (
                    f"指定书目：《{book_title}》{author_hint}\n"
                    f"你上次返回的 book_title 是「{wrong}」，与指定书目不符。\n"
                    f"请重新只从《{book_title}》摘录原文；"
                    f"JSON 中 book_title 必须严格等于「{book_title}」。"
                )

            raw = await self._call_deepseek(
                api_key=api_key,
                system=system,
                user_prompt=prompt,
                temperature=temperature,
                top_p=top_p,
                presence_penalty=presence_penalty,
            )
            parsed = self._parse(raw)
            if not book_title or _titles_match(book_title, parsed.book_title):
                break

        assert parsed is not None
        if book_title:
            parsed.book_title = book_title
        if book_author:
            parsed.author = book_author
        parsed.source = "deepseek"
        return parsed

    async def _call_deepseek(
        self,
        *,
        api_key: str,
        system: str,
        user_prompt: str,
        temperature: float,
        top_p: float | None = None,
        presence_penalty: float | None = None,
    ) -> str:
        url = f"{self._settings.deepseek_api_base}/chat/completions"
        payload: dict = {
            "model": self._settings.deepseek_model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": temperature,
            "max_tokens": PAGE_MAX_TOKENS,
            "stream": False,
        }
        if top_p is not None:
            payload["top_p"] = top_p
        if presence_penalty is not None:
            payload["presence_penalty"] = presence_penalty
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

        return choices[0].get("message", {}).get("content", "")

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
