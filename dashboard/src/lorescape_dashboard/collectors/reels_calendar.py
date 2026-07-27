"""Reels 選點排程：解析 marketing/content-calendar/_reels-place-calendar.md。"""
from __future__ import annotations

import re

from ..config import CALENDAR_PATH

_TITLE_RANGE_RE = re.compile(r"（(\d{4})/(\d{2})/\d{2}\s*–\s*[\d/]+）")
# 排程列：| 7/11 六 | 富士山 | Fujisan... | 日本 |
_ROW_RE = re.compile(
    r"^\|\s*(\d{1,2})/(\d{1,2})\s*[一二三四五六日]\s*\|"
    r"\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$"
)
_HEADING_RE = re.compile(r"^#{1,6}\s+(.+)$")
# 只有「## Week N（…）」段落底下的表才是排程；「開場 hook 指定」表同為
# 「日期＋三欄」的形狀，不靠段落區分會被一起收進來（欄位還會錯位）。
_WEEK_HEADING_RE = re.compile(r"^Week\s")


def parse_calendar(text: str) -> dict:
    """解析週表列成日期排程；月份小於起始月視為跨年（年 +1）。"""
    title_match = _TITLE_RANGE_RE.search(text)
    year = int(title_match.group(1)) if title_match else None
    start_month = int(title_match.group(2)) if title_match else None
    range_text = ""
    if title_match:
        range_text = title_match.group(0).strip("（）")

    entries = []
    in_week_section = False
    for line in text.splitlines():
        stripped = line.strip()
        heading = _HEADING_RE.match(stripped)
        if heading:
            in_week_section = bool(_WEEK_HEADING_RE.match(heading.group(1).strip()))
            continue
        if not in_week_section:
            continue
        m = _ROW_RE.match(stripped)
        if not m:
            continue
        month, day = int(m.group(1)), int(m.group(2))
        entry_year = year or 0
        if start_month and month < start_month:
            entry_year += 1
        entries.append(
            {
                "date": f"{entry_year:04d}-{month:02d}-{day:02d}",
                "place": m.group(3).strip(),
                "db_title": m.group(4).strip(),
                "category": m.group(5).strip(),
            }
        )
    return {"entries": entries, "range": range_text}


def collect() -> dict:
    if not CALENDAR_PATH.exists():
        raise RuntimeError(f"排程檔不存在：{CALENDAR_PATH}")
    return parse_calendar(CALENDAR_PATH.read_text(encoding="utf-8"))
