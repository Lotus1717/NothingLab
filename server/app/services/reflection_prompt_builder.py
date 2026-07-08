"""阅读思考 Prompt 构建 — 四种模式 + 模式识别。"""

from __future__ import annotations

from app.models.reading_mode import DEPTH_STAGES, MODE_LABELS

BASE_RULES = """通用规则：
- 只输出一个问题，15-30 字
- 不要替用户写感想或总结
- 语气像朋友聊天，不像老师出题
- 用户写得很短时追问具体细节；写得较长时追问核心矛盾"""

MODE_DETECTION_SYSTEM = """你是阅读分类助手。根据书名、作者和书摘片段，判断最适合的阅读思考模式：
- resonance（共鸣式）：文学、散文、传记、诗歌
- comprehension（理解式）：科普、教材、商业、历史
- dialectic（辩证式）：哲学、思想、争议性社科
- application（应用式）：方法论、技能、自我提升

只输出 JSON：{"reading_mode": "...", "confidence": 0.0-1.0, "reason": "简短说明"}"""

MODE_FIRST_TURN: dict[str, str] = {
    "resonance": """你是用户的阅读思考伙伴。用户刚读完一段文学/叙事类书摘。
提出一个开放式问题，帮 TA 开始感受这段文字。方向：触动、共鸣、印象最深的细节。""",
    "comprehension": """你是用户的阅读思考伙伴。用户刚读完一段知识/论述类书摘。
提出一个开放式问题，帮 TA 开始理解这段内容。方向：用自己的话复述核心观点。""",
    "dialectic": """你是用户的阅读思考伙伴。用户刚读完一段哲学/思辨类书摘。
提出一个开放式问题，帮 TA 开始审视这段论述。方向：澄清概念或追问论证前提。""",
    "application": """你是用户的阅读思考伙伴。用户刚读完一段方法论/实用类书摘。
提出一个开放式问题，帮 TA 开始联系自身。方向：定位自己的具体场景或现状。""",
}

MODE_FOLLOWUP: dict[str, str] = {
    "resonance": """你是用户的阅读思考伙伴，当前模式：共鸣式。
根据对话历史，提出下一个问题帮用户深入感受。按层次递进：触动→连接个人经历→细节五感→提炼感受→行动改变。
判断是否可以结束：用户已连贯描述有细节、有情感的个人联想 → can_conclude: true""",
    "comprehension": """你是用户的阅读思考伙伴，当前模式：理解式。
根据对话历史，提出下一个问题帮用户深入理解。按层次递进：复述→联系已知→检验反例→辨析概念→举例应用。
判断是否可以结束：用户能用自己的话复述核心观点并举例 → can_conclude: true""",
    "dialectic": """你是用户的阅读思考伙伴，当前模式：辩证式。
根据对话历史，提出下一个问题帮用户深入思辨。按层次递进：澄清概念→梳理论证→质疑前提→反面论证→形成立场。
判断是否可以结束：用户能说出作者论证并表达自己的立场及理由 → can_conclude: true""",
    "application": """你是用户的阅读思考伙伴，当前模式：应用式。
根据对话历史，提出下一个问题帮用户落地行动。按层次递进：定位场景→诊断障碍→提取方法→计划第一步→预判阻力。
判断是否可以结束：用户有具体、可在一周内执行的行动项 → can_conclude: true""",
}

FALLBACK_FIRST: dict[str, list[str]] = {
    "resonance": [
        "这段里，哪一句话最打动你？",
        "读到这里，你想到了生活中的什么事？",
        "如果用一句话回应这段文字，你会说什么？",
    ],
    "comprehension": [
        "用自己的话，这段话的核心观点是什么？",
        "这段内容和你的已有认知有什么联系？",
        "读完后，你能举一个生活中的例子吗？",
    ],
    "dialectic": [
        "作者在这里的核心论点是什么？",
        "你同意作者的看法吗？为什么？",
        "这段话的前提假设是什么？",
    ],
    "application": [
        "这段话的方法，可以用在你的哪个场景？",
        "按这个思路，你明天可以先试哪一步？",
        "你现在最大的障碍是什么？",
    ],
}


def build_mode_detection_user(
    book_title: str, author: str, content: str
) -> str:
    author_line = f"作者：{author}\n" if author.strip() else ""
    return (
        f"书名：《{book_title}》\n"
        f"{author_line}"
        f"书摘片段：{content[:600]}"
    )


def build_first_turn_user(
    mode: str, book_title: str, author: str, content: str
) -> str:
    author_line = f"作者：{author}\n" if author.strip() else ""
    return (
        f"书名：《{book_title}》\n"
        f"{author_line}"
        f"今日读到的内容：{content[:600]}\n"
        "请提一个问题，引导用户开始思考。"
    )


def build_followup_user(
    mode: str,
    book_title: str,
    content: str,
    depth_level: int,
    depth_label: str,
    history: list[dict[str, str]],
) -> str:
    history_text = ""
    for item in history:
        role = "用户" if item.get("role") == "user" else "AI"
        history_text += f"{role}：{item.get('content', '')}\n"

    stages = DEPTH_STAGES.get(mode, DEPTH_STAGES["resonance"])
    return (
        f"书名：《{book_title}》\n"
        f"书摘：{content[:600]}\n"
        f"当前模式：{MODE_LABELS.get(mode, mode)}\n"
        f"当前深度：第 {depth_level} 层（{depth_label}），共 {len(stages)} 层\n"
        f"深度层级参考：{' → '.join(stages)}\n\n"
        f"对话历史（assistant 为你上一轮提出的问题）：\n{history_text}\n"
        '输出 JSON：{"question": "...", "depth_level": N, "depth_label": "...", "can_conclude": true/false}'
    )


def build_followup_system(mode: str) -> str:
    return f"{MODE_FOLLOWUP.get(mode, MODE_FOLLOWUP['resonance'])}\n\n{BASE_RULES}"
