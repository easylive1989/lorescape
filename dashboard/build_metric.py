#!/usr/bin/env python3
"""把 data/metrics/*.csv 整形後內嵌成單檔 dashboard/out/metric.html。

無框架、無執行期相依：產出的 HTML 自帶資料，雙擊即可離線開啟。
要看最新數據就重跑一次本指令（file:// 下瀏覽器 CORS 會擋 fetch 本機 CSV，
所以資料只能在建置時內嵌）。

    uv run python build_metric.py        # 於 dashboard/ 內
    python3 dashboard/build_metric.py    # 或從 repo 根目錄
"""
from __future__ import annotations

import csv
import json
import re
from datetime import date, datetime, timedelta
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "data" / "metrics"
CALENDAR = REPO_ROOT / "marketing" / "content-calendar" / "_reels-place-calendar.md"
OUT = Path(__file__).resolve().parent / "out" / "metric.html"

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TREND_DAYS = 30
POST_DAYS = 21


# ---------------------------------------------------------------- CSV helpers

def read_rows(name: str) -> list[dict]:
    path = DATA_DIR / f"{name}.csv"
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(value) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(str(value).replace(",", "").replace("%", ""))
    except ValueError:
        return None


def total(rows: list[dict], col: str, start: str, end: str, key: str = "date") -> float:
    out = 0.0
    for r in rows:
        d = r.get(key, "")
        if start <= d <= end:
            v = num(r.get(col))
            if v is not None:
                out += v
    return out


def latest_date(rows: list[dict], key: str = "date") -> str | None:
    dates = [r[key] for r in rows if DATE_RE.match(r.get(key, ""))]
    return max(dates) if dates else None


# ------------------------------------------------------------ reel style map

def parse_style_map() -> dict[str, dict]:
    """從 reels calendar 讀每日 style（謎/閉）與景點名，key 為 YYYY-MM-DD。

    calendar 有兩種寫法，兩種都要吃：
    - Week 2 起的表格有第 5 欄 style；Week 1 的表格只有 4 欄（無 style）
    - 每期的「style 排程」是散文（`8/3 謎、8/4 閉、…`），Week 1 只有這裡有
    """
    if not CALENDAR.exists():
        return {}
    text = CALENDAR.read_text(encoding="utf-8")
    year = date.today().year
    out: dict[str, dict] = {}

    def key_of(mm: str, dd: str) -> str:
        return f"{year}-{int(mm):02d}-{int(dd):02d}"

    # 表格列：4 欄（日期｜景點｜DB 標題｜類型）或 5 欄（多一個 style）
    row_re = re.compile(
        r"^\|\s*(\d{1,2})/(\d{1,2})\s*[一二三四五六日]?\s*\|\s*([^|]+?)\s*\|"
        r"\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|(?:\s*(謎|閉)\s*\|)?\s*$"
    )
    for line in text.splitlines():
        m = row_re.match(line.strip())
        if not m:
            continue
        mm, dd, place, _title, kind, style = m.groups()
        entry = out.setdefault(key_of(mm, dd), {})
        entry["place"] = re.sub(r"\*\*|（.*?）", "", place).strip()
        entry["kind"] = kind.strip()
        if style:
            entry["style"] = style

    # 散文排程：`8/3 謎、8/4 閉、…`（表格列的日期與 style 相隔數欄，不會誤中）
    for mm, dd, style in re.findall(r"(\d{1,2})/(\d{1,2})\s*(謎|閉)(?=[、。，\s])", text):
        out.setdefault(key_of(mm, dd), {}).setdefault("style", style)

    return out


# -------------------------------------------------------------------- shaping

def build_payload() -> dict:
    today = date.today()
    cur_end = (today - timedelta(days=1)).isoformat()
    cur_start = (today - timedelta(days=7)).isoformat()
    prev_end = (today - timedelta(days=8)).isoformat()
    prev_start = (today - timedelta(days=14)).isoformat()

    ig = read_rows("ig")
    ga4 = read_rows("ga4")
    gsc = read_rows("gsc")
    ios = read_rows("store_ios")
    rc = read_rows("revenuecat")
    narration = read_rows("narration")
    posts = read_rows("ig_posts")
    insights = read_rows("ig_reels_insights")

    def wow(rows, col):
        return total(rows, col, cur_start, cur_end), total(rows, col, prev_start, prev_end)

    reach_c, reach_p = wow(ig, "reach")
    pv_c, pv_p = wow(ig, "profile_views")
    web_c, web_p = wow(ga4, "web_active_users")
    ios_c, ios_p = wow(ios, "downloads")
    gsc_c, gsc_p = wow(gsc, "clicks")

    # followers 是快照欄，取窗內最後一筆非空值
    def snapshot(rows, col, start, end):
        vals = [num(r.get(col)) for r in rows
                if start <= r.get("date", "") <= end and num(r.get(col)) is not None]
        return vals[-1] if vals else None

    fol_c = snapshot(ig, "followers_count", cur_start, cur_end)
    fol_p = snapshot(ig, "followers_count", prev_start, prev_end)

    ratio_c = (pv_c / reach_c * 100) if reach_c else None
    ratio_p = (pv_p / reach_p * 100) if reach_p else None

    kpis = [
        {"label": "IG 週觸及", "value": reach_c, "prev": reach_p, "fmt": "int"},
        {"label": "IG 粉絲", "value": fol_c, "prev": fol_p, "fmt": "int",
         "note": "期末快照"},
        {"label": "個人檔案瀏覽 / 觸及", "value": ratio_c, "prev": ratio_p,
         "fmt": "pct", "threshold": 1.5,
         "note": "門檻 1.5%（BACKLOG F15 T4）"},
        {"label": "Landing 週活躍", "value": web_c, "prev": web_p, "fmt": "int"},
        {"label": "iOS 週下載", "value": ios_c, "prev": ios_p, "fmt": "int"},
        {"label": "搜尋點擊", "value": gsc_c, "prev": gsc_p, "fmt": "int",
         "note": "GSC 天然落後 2–3 天"},
    ]

    trend_start = (today - timedelta(days=TREND_DAYS)).isoformat()
    ig_daily = [
        {"date": r["date"], "reach": num(r.get("reach")) or 0,
         "pv": num(r.get("profile_views")) or 0}
        for r in ig if trend_start <= r.get("date", "") <= cur_end
    ]
    followers = [
        {"date": r["date"], "v": num(r.get("followers_count"))}
        for r in ig
        if trend_start <= r.get("date", "") <= cur_end
        and num(r.get("followers_count")) is not None
    ]
    ga4_daily = [
        {"date": r["date"],
         "web": num(r.get("web_active_users")) or 0,
         "ios": num(r.get("ios_active_users")) or 0,
         "android": num(r.get("android_active_users")) or 0}
        for r in ga4 if trend_start <= r.get("date", "") <= cur_end
    ]

    # 每則貼文取最新一次觀察（ig_posts 是逐日時間序列）
    post_start = (today - timedelta(days=POST_DAYS)).isoformat()
    newest: dict[str, dict] = {}
    for r in posts:
        if r.get("posted_date", "") >= post_start:
            newest[r["media_id"]] = r  # 檔案已依 posted→media→obs 排序，後者覆蓋
    by_post = sorted(
        ({"date": r["posted_date"],
          "type": "Reels" if r.get("type") == "REELS" else "Carousel",
          "reach": num(r.get("reach")) or 0,
          "caption": (r.get("caption") or "")[:34]}
         for r in newest.values()),
        key=lambda x: x["date"],
    )

    styles = parse_style_map()
    reels_skip = []
    for r in insights:
        if r.get("checkpoint") != "24h":
            continue
        d = r.get("posted_date", "")
        meta = styles.get(d, {})
        reels_skip.append({
            "date": d,
            "place": meta.get("place") or (r.get("caption") or "")[:12],
            "style": meta.get("style"),
            "skip": num(r.get("skip_rate_pct")),
            "views": num(r.get("views")) or 0,
        })
    reels_skip = [x for x in reels_skip if x["skip"] is not None]
    reels_skip.sort(key=lambda x: x["date"])
    reels_skip = reels_skip[-14:]

    funnel = [
        {"stage": "IG 觸及", "value": reach_c},
        {"stage": "個人檔案瀏覽", "value": pv_c},
        {"stage": "Landing 活躍", "value": web_c},
        {"stage": "iOS 下載", "value": ios_c},
    ]

    sources = []
    for name in ["ig", "ga4", "gsc", "store_ios", "store_ios_pages",
                 "store_android", "revenuecat", "narration", "retention"]:
        rows = read_rows(name)
        sources.append({"name": name, "latest": latest_date(rows) or "—",
                        "rows": len(rows)})
    for name, key in [("ig_posts", "obs_date"), ("ig_reels_insights", "obs_date")]:
        rows = read_rows(name)
        sources.append({"name": name, "latest": latest_date(rows, key) or "—",
                        "rows": len(rows)})

    rc_latest = rc[-1] if rc else {}

    return {
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "window": {"cur": [cur_start, cur_end], "prev": [prev_start, prev_end]},
        "kpis": kpis,
        "ig_daily": ig_daily,
        "followers": followers,
        "ga4_daily": ga4_daily,
        "posts": by_post,
        "reels_skip": reels_skip,
        "funnel": funnel,
        "sources": sources,
        "revenuecat": {
            "date": rc_latest.get("date", "—"),
            "mrr": rc_latest.get("mrr", "—"),
            "subs": rc_latest.get("active_subscriptions", "—"),
            "active28": rc_latest.get("active_users_28d", "—"),
        },
        "narration": {
            "started": total(narration, "narration_started", cur_start, cur_end),
            "completed": total(narration, "narration_completed", cur_start, cur_end),
        },
    }


def main() -> None:
    payload = build_payload()
    template = (Path(__file__).resolve().parent / "metric_template.html").read_text(
        encoding="utf-8"
    )
    html = template.replace(
        "/*__DATA__*/null",
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
    )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    size = OUT.stat().st_size / 1024
    print(f"寫出 {OUT}  ({size:.0f} KB)")
    print(f"資料截至 {payload['window']['cur'][1]}，建置時間 {payload['generated_at']}")


if __name__ == "__main__":
    main()
