"""把 collector 資料渲染成單一自包含 HTML 面板（無外部資源、無 JS 依賴）。

視覺規範依 dataviz skill 參考色盤：light/dark 雙模式、固定 status 色、
sparkline 2px 線 + 端點 dot、表格 tabular-nums。
"""
from __future__ import annotations

import calendar
import html
import re
from datetime import date

from .collectors.schedule import compute_for_date

_E = html.escape

_CSS = """
:root{
  --page:#f9f9f7;--surface:#fcfcfb;--ink:#0b0b0b;--ink-2:#52514e;--muted:#898781;
  --grid:#e1e0d9;--border:rgba(11,11,11,.10);--series:#2a78d6;
  --good:#0ca30c;--good-text:#006300;--warning:#fab219;--critical:#d03b3b;
  --wash:rgba(42,120,214,.10);
}
@media (prefers-color-scheme:dark){:root{
  --page:#0d0d0d;--surface:#1a1a19;--ink:#fff;--ink-2:#c3c2b7;--muted:#898781;
  --grid:#2c2c2a;--border:rgba(255,255,255,.10);--series:#3987e5;
  --good:#0ca30c;--good-text:#0ca30c;--warning:#fab219;--critical:#d03b3b;
  --wash:rgba(57,135,229,.12);
}}
*{box-sizing:border-box;margin:0}
body{background:var(--page);color:var(--ink);
  font:30px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif;padding:0 20px 80px}
main{max-width:none;margin:0 auto}
a{color:var(--series);text-decoration:none}
header{display:flex;flex-wrap:wrap;align-items:baseline;gap:12px;
  padding:28px 0 8px;border-bottom:1px solid var(--grid)}
header h1{font-size:40px;letter-spacing:.04em}
header .stamp{color:var(--muted);font-size:26px;margin-left:auto}
.tabs{display:flex;gap:4px;padding:12px 0 0;position:sticky;top:0;background:var(--page);
  z-index:2;border-bottom:1px solid var(--grid)}
.tabs button{appearance:none;border:1px solid transparent;border-bottom:none;background:none;
  color:var(--ink-2);font:28px/1 system-ui,-apple-system,"Segoe UI",sans-serif;
  padding:10px 16px;border-radius:8px 8px 0 0;cursor:pointer}
.tabs button:hover{color:var(--ink)}
.tabs button[aria-selected="true"]{background:var(--surface);border-color:var(--border);
  color:var(--ink);font-weight:600;position:relative;top:1px}
.panel{display:none}
.panel.active{display:block}
h2{font-size:32px;margin:36px 0 14px;display:flex;align-items:center;gap:8px}
h2 .hash{color:var(--muted);font-weight:400}
section{scroll-margin-top:48px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-top:20px}
.tile{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px 16px}
.tile .label{font-size:24px;color:var(--ink-2)}
.tile .value{font-size:44px;font-weight:600;margin-top:2px;display:flex;align-items:center;gap:8px}
.dot{width:10px;height:10px;border-radius:50%;flex:none}
.dot.good{background:var(--good)}.dot.warning{background:var(--warning)}
.dot.critical{background:var(--critical)}.dot.muted{background:var(--muted)}
table{border-collapse:collapse;width:100%;background:var(--surface);
  border:1px solid var(--border);border-radius:10px;overflow:hidden;font-size:28px}
th,td{text-align:left;padding:8px 12px;border-top:1px solid var(--grid);
  font-variant-numeric:tabular-nums}
thead th{border-top:none;color:var(--ink-2);font-weight:500;font-size:24px;background:var(--surface)}
.num{text-align:right}
.status-good{color:var(--good-text)}.status-warning{color:#8a6100}
@media (prefers-color-scheme:dark){.status-warning{color:var(--warning)}}
.status-critical{color:var(--critical)}
.callout{background:var(--surface);border:1px solid var(--border);border-left:3px solid var(--series);
  border-radius:8px;padding:10px 14px;margin:10px 0;font-size:28px}
.callout.warn{border-left-color:var(--warning)}
.callout.error{border-left-color:var(--critical)}
.progress{height:8px;background:var(--grid);border-radius:4px;overflow:hidden;margin:6px 0 4px}
.progress i{display:block;height:100%;background:var(--series);border-radius:4px}
.kanban{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:12px;align-items:start}
.kanban .col{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:10px}
.kanban .col>h3{font-size:24px;color:var(--ink-2);font-weight:500;padding:2px 4px 8px}
.card{border:1px solid var(--grid);border-radius:8px;margin-bottom:8px;background:var(--page)}
.card summary{padding:8px 10px;cursor:pointer;font-size:28px;list-style:none}
.card summary::-webkit-details-marker{display:none}
.card .meta{color:var(--muted);font-size:24px}
.card ul{padding:2px 12px 10px 26px;font-size:26px;color:var(--ink-2)}
.card li.done{text-decoration:line-through;color:var(--muted)}
ul.plain{list-style:none;padding:0}
ul.plain li{padding:3px 0;font-size:28px}
.fail{color:var(--critical);font-size:26px;padding:2px 0}
.metric-card{background:var(--surface);border:1px solid var(--border);border-radius:10px;
  padding:14px 16px;margin-bottom:14px}
.metric-head{display:flex;align-items:baseline;gap:10px;margin-bottom:8px}
.metric-head b{font-size:28px}
.metric-head span{color:var(--muted);font-size:24px}
.stats-row{display:flex;flex-wrap:wrap;gap:8px 28px;margin-bottom:6px}
.stat .label{font-size:24px;color:var(--ink-2)}
.stat .value{font-size:38px;font-weight:600}
.delta{font-size:24px;font-weight:500;margin-left:4px}
.delta.up{color:var(--good-text)}.delta.down{color:var(--critical)}.delta.flat{color:var(--muted)}
details.table-fold{margin-top:8px;font-size:26px}
details.table-fold summary{color:var(--muted);cursor:pointer;font-size:24px}
.spark{display:block;margin-top:4px}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chip{background:var(--surface);border:1px solid var(--border);border-radius:8px;
  padding:8px 12px;font-size:28px;display:flex;gap:8px;align-items:center}
footer{margin-top:48px;color:var(--muted);font-size:24px}
.sec-stamp{color:var(--muted);font-size:24px;margin-bottom:8px}
button.refresh{appearance:none;border:1px solid var(--border);background:var(--surface);
  color:var(--ink-2);border-radius:6px;font-size:26px;line-height:1;padding:4px 8px;
  cursor:pointer;margin-left:4px}
button.refresh:hover{color:var(--series)}
button.refresh:disabled{opacity:.5;cursor:wait}
.calendar{display:grid;grid-template-columns:repeat(7,1fr);gap:4px;margin:10px 0}
.cal-head{text-align:center;font-size:24px;color:var(--ink-2);padding:4px 0}
.cal-day{background:var(--surface);border:1px solid var(--border);border-radius:8px;
  min-height:64px;padding:6px 8px;font-size:24px;cursor:pointer;display:flex;
  flex-direction:column;gap:2px}
.cal-day b{font-size:26px;font-variant-numeric:tabular-nums}
.cal-day.out{background:none;border-color:transparent;cursor:default}
.cal-day:not(.out):hover{border-color:var(--series)}
.cal-day.today b{color:var(--series)}
.cal-day.selected{border-color:var(--series);box-shadow:0 0 0 1px var(--series);
  background:var(--wash)}
.cal-tag{color:var(--ink-2);white-space:nowrap}
.cal-detail{margin-top:12px}
.cal-detail h3{font-size:26px;color:var(--ink-2);margin-bottom:6px}
.table-scroll{overflow-x:auto;margin-bottom:14px}
table.pivot th:first-child,table.pivot td:first-child{position:sticky;left:0;
  background:var(--surface);z-index:1;white-space:nowrap}
table.pivot thead th{white-space:nowrap}
"""


# ---------- 小工具 ----------


def _num(value: float | None) -> str:
    if value is None:
        return "–"
    return str(int(value)) if value == int(value) else str(value)


def _delta_html(value: float | None) -> str:
    if value is None:
        return ""
    if value > 0:
        return f'<span class="delta up">▲ +{_num(value)}</span>'
    if value < 0:
        return f'<span class="delta down">▼ {_num(value)}</span>'
    return '<span class="delta flat">±0</span>'


def _strip_md(text: str) -> str:
    return re.sub(r"\*\*(.+?)\*\*", r"\1", text).replace("`", "")


def _error_card(section: str, message: str) -> str:
    return f'<div class="callout error"><b>{_E(section)} 收集失敗：</b>{_E(message)}</div>'


def sparkline_svg(points: list[tuple[str, float]], width: int = 260, height: int = 48) -> str:
    """30 天趨勢 sparkline：2px 線、10% 面積 wash、端點 dot（含 2px 表面 ring）。"""
    if len(points) < 2:
        return ""
    values = [v for _, v in points]
    lo, hi = min(values), max(values)
    span = (hi - lo) or 1.0
    pad = 5
    step = (width - pad * 2) / (len(points) - 1)

    def xy(i: int, v: float) -> tuple[float, float]:
        return (
            round(pad + i * step, 1),
            round(pad + (height - pad * 2) * (1 - (v - lo) / span), 1),
        )

    coords = [xy(i, v) for i, (_, v) in enumerate(points)]
    poly = " ".join(f"{x},{y}" for x, y in coords)
    area = f"{pad},{height - pad} {poly} {coords[-1][0]},{height - pad}"
    end_x, end_y = coords[-1]
    titles = "".join(
        f'<circle cx="{x}" cy="{y}" r="7" fill="transparent">'
        f"<title>{_E(d)}：{_num(v)}</title></circle>"
        for (x, y), (d, v) in zip(coords, points)
    )
    return (
        f'<svg class="spark" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-label="近 30 天趨勢">'
        f'<polygon points="{area}" fill="var(--wash)"/>'
        f'<polyline points="{poly}" fill="none" stroke="var(--series)" '
        f'stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>'
        f'<circle cx="{end_x}" cy="{end_y}" r="4" fill="var(--series)" '
        f'stroke="var(--surface)" stroke-width="2"/>'
        f"{titles}</svg>"
    )


# ---------- 健康燈號 ----------


def health_signals(data: dict) -> list[dict]:
    signals = []

    tests = data.get("tests")
    if tests:
        failed = sum(s.get("failed", 0) for s in tests["suites"])
        total = sum(s.get("total", 0) for s in tests["suites"])
        signals.append(
            {
                "label": "測試",
                "value": f"{total - failed}/{total}",
                "level": "good" if failed == 0 else "critical",
            }
        )
    else:
        signals.append({"label": "測試", "value": "無資料", "level": "muted"})

    deploys = data.get("deploys")
    if deploys:
        behind = [s["behind_master"] for s in deploys["services"] if s.get("behind_master")]
        if behind:
            signals.append({"label": "部署", "value": f"最多落後 {max(behind)}", "level": "warning"})
        else:
            signals.append({"label": "部署", "value": "與 master 同步", "level": "good"})
    else:
        signals.append({"label": "部署", "value": "無資料", "level": "muted"})

    story = data.get("daily_story")
    if story:
        if story["all_published"]:
            signals.append({"label": "今日故事", "value": "已發布", "level": "good"})
        elif story["posts"]:
            signals.append({"label": "今日故事", "value": "進行中", "level": "warning"})
        else:
            signals.append({"label": "今日故事", "value": "尚無記錄", "level": "critical"})
    else:
        signals.append({"label": "今日故事", "value": "無資料", "level": "muted"})

    backlog = data.get("backlog")
    checkpoints = [
        c
        for e in (backlog or {}).get("epics", [])
        for c in e["checkpoints"]
        if not c["done"]
    ]
    if checkpoints:
        days = min(c["days_left"] for c in checkpoints)
        signals.append(
            {
                "label": "Epic 檢核",
                "value": f"倒數 {days} 天",
                "level": "critical" if days <= 7 else "warning" if days <= 14 else "good",
            }
        )
    return signals


def _tiles(data: dict) -> str:
    tiles = "".join(
        f'<div class="tile"><div class="label">{_E(s["label"])}</div>'
        f'<div class="value"><i class="dot {s["level"]}"></i>{_E(s["value"])}</div></div>'
        for s in health_signals(data)
    )
    return f'<div class="tiles">{tiles}</div>'


# ---------- Backlog（Epic + 看板） ----------


def _epic_html(backlog: dict) -> str:
    parts = []
    for epic in backlog["epics"]:
        done, total = epic["features_done"], epic["features_total"]
        percent = round(done / total * 100) if total else 0
        parts.append(
            f'<div class="metric-card"><div class="metric-head">'
            f'<b>{_E(epic["id"])} {_E(epic["title"])}</b>'
            f'<span>{_E(epic["status"] or "?")}</span></div>'
            f'<div class="progress"><i style="width:{percent}%"></i></div>'
            f'<div class="card .meta" style="font-size:26px;color:var(--ink-2)">'
            f'{done}/{total} features'
            + (f'　·　目標：{_E(epic["goal"])}' if epic["goal"] else "")
            + "</div>"
        )
        for cp in epic["checkpoints"]:
            if cp["done"]:
                continue
            css = "error" if cp["days_left"] <= 7 else "warn"
            parts.append(
                f'<div class="callout {css}">⏳ 檢核點 {_E(cp["date"])}（倒數 {cp["days_left"]} 天）：'
                f'{_E(cp["text"])}</div>'
            )
        parts.append("</div>")
    return "".join(parts)


def _pending_html(backlog: dict) -> str:
    pending = backlog.get("pending_deploy")
    if not pending or not any(not i["done"] for i in pending["items"]):
        return ""
    items = "".join(
        f'<li class="{"done" if i["done"] else ""}">{"✅" if i["done"] else "⬜"} '
        f'{_E(_strip_md(i["text"]))}</li>'
        for i in pending["items"]
    )
    return (
        f'<div class="callout warn"><b>{_E(_strip_md(pending["title"]))}</b>'
        f'<ul class="plain">{items}</ul></div>'
    )


def _feature_card(feature: dict) -> str:
    tasks = "".join(
        f'<li class="{"done" if t["done"] else ""}">{_E(_strip_md(t["text"]))}</li>'
        for t in feature["tasks"]
    ) or '<li>（無 tasks）</li>'
    epic_tag = f'（{feature["epic"]}）' if feature["epic"] else ""
    return (
        f'<details class="card"><summary><b>{_E(feature["id"])}</b> {_E(feature["title"])}'
        f'<div class="meta">{_E(feature["status"] or "?")}{_E(epic_tag)}　'
        f'{feature["tasks_done"]}/{feature["tasks_total"]}</div></summary>'
        f"<ul>{tasks}</ul></details>"
    )


def _done_month(feature: dict) -> str | None:
    m = re.search(r"(\d{4}-\d{2})", feature["status"] or "")
    return m.group(1) if m else None


def _kanban_html(backlog: dict, current_month: str) -> str:
    todo, doing, done_now, done_old = [], [], [], []
    for f in backlog["features"]:
        if f["done"]:
            month = _done_month(f)
            (done_now if month in (None, current_month) else done_old).append(f)
        elif "進行" in (f["status"] or ""):
            doing.append(f)
        else:
            todo.append(f)

    def col(title: str, features: list[dict], extra: str = "") -> str:
        cards = "".join(_feature_card(f) for f in features) or (
            '<div class="card"><summary style="padding:8px 10px;color:var(--muted)">（無）</summary></div>'
            if not extra else ""
        )
        return f'<div class="col"><h3>{_E(title)}（{len(features)}）</h3>{cards}{extra}</div>'

    old_fold = ""
    if done_old:
        old_cards = "".join(_feature_card(f) for f in done_old)
        old_fold = (
            f'<details class="table-fold"><summary>更早完成（{len(done_old)}）</summary>'
            f"{old_cards}</details>"
        )
    return (
        '<div class="kanban">'
        + col("待辦", todo)
        + col("進行中", doing)
        + col(f"已完成・{current_month}", done_now, old_fold)
        + "</div>"
    )


# ---------- 部署 / 測試 / E2E ----------


def _deploys_html(deploys: dict) -> str:
    rows = []
    for s in deploys["services"]:
        if s["deployed_at"] is None:
            rows.append(
                f"<tr><td>{_E(s['service'])}</td><td>（無成功部署記錄）</td><td>–</td><td>–</td></tr>"
            )
            continue
        behind = s["behind_master"]
        status = (
            '<span class="status-good">✓ 同步</span>'
            if behind == 0
            else f'<span class="status-warning">⚠ 落後 {behind}</span>'
        )
        when = s["deployed_at"].replace("T", " ").replace("Z", " UTC")
        commit = (
            f'<a href="{_E(s["run_url"])}">{_E(s["commit"])}</a>'
            if s.get("run_url")
            else _E(s["commit"])
        )
        rows.append(
            f"<tr><td>{_E(s['service'])}</td><td>{_E(when)}</td><td>{commit}</td><td>{status}</td></tr>"
        )
    return (
        "<table><thead><tr><th>服務</th><th>最後部署</th><th>commit</th><th>vs master</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )


def _tests_html(tests: dict) -> str:
    rows = []
    failures: list[dict] = []
    for s in tests["suites"]:
        extras = []
        if s.get("coverage_percent") is not None:
            extras.append(f"cov {s['coverage_percent']}%")
        analyze = s.get("analyze")
        if analyze:
            extras.append("analyze ✓" if analyze["ok"] else "analyze ✗")
        status = (
            '<span class="status-good">✓ 全數通過</span>'
            if s["failed"] == 0
            else f'<span class="status-critical">✗ {s["failed"]} 失敗</span>'
        )
        rows.append(
            f"<tr><td>{_E(s['suite'])}</td>"
            f'<td class="num">{s["passed"]}/{s["total"]}</td>'
            f"<td>{status}</td>"
            f'<td class="num">{round(s["duration_seconds"])}s</td>'
            f"<td>{_E('、'.join(extras) or '–')}</td></tr>"
        )
        failures.extend(s.get("failures", []))

    out = (
        "<table><thead><tr><th>套件</th><th>通過</th><th>狀態</th><th>耗時</th><th>其他</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )
    if failures:
        items = "".join(
            f'<div class="fail">✗ {_E(f["name"])} — '
            f'{_E((f.get("error") or "").splitlines()[0] if f.get("error") else "")}</div>'
            for f in failures[:30]
        )
        out += f'<div class="callout error"><b>失敗案例</b>{items}</div>'
    return out


def _e2e_html(e2e: dict) -> str:
    parts = []
    for group in e2e["groups"]:
        cases = "".join(f"<li>{_E(c)}</li>" for c in group["cases"])
        parts.append(
            f'<details class="card" open><summary><b>{_E(group["file"])}</b>'
            f'<div class="meta">{_E(group["group"])}　{len(group["cases"])} cases</div></summary>'
            f"<ul>{cases}</ul></details>"
        )
    return "".join(parts)


# ---------- 產品數據 ----------

_HEADLINES = {
    "gsc": ["clicks", "impressions"],
    "ga4": ["web_active_users", "ios_active_users", "android_active_users"],
    "ig": ["reach", "followers_count"],
    "revenuecat": ["mrr", "active_subscriptions", "active_trials"],
    "store_ios": ["downloads", "avg_rating"],
    "store_ios_pages": ["impressions", "product_page_views"],
    "store_android": ["installs", "avg_rating_total"],
    "narration": ["completion_rate"],
    "retention": ["cohort_size", "d1_rate", "d7_rate"],
}


def _to_float(value) -> float | None:
    try:
        return float(str(value).replace(",", "").replace("%", ""))
    except ValueError:
        return None


def _metric_card(tab: dict) -> str:
    if "error" in tab:
        return _error_card(tab["name"], tab["error"])

    headline_cols = [
        c for c in _HEADLINES.get(tab["name"], list(tab["stats"])[:3]) if c in tab["stats"]
    ]
    stats = "".join(
        f'<div class="stat"><div class="label">{_E(col)}</div>'
        f'<div class="value">{_num(tab["stats"][col]["latest"])}'
        f'{_delta_html(tab["stats"][col]["delta"])}</div></div>'
        for col in headline_cols
    )

    spark = ""
    if headline_cols:
        col_index = tab["headers"].index(headline_cols[0])
        points = [
            (row[0], v)
            for row in tab.get("rows_30d", [])
            if col_index < len(row) and (v := _to_float(row[col_index])) is not None
        ]
        spark = sparkline_svg(points)
        if spark:
            spark = (
                f'<div class="stat"><div class="label">{_E(headline_cols[0])}・近 30 天</div>'
                f"{spark}</div>"
            )

    header_cells = "".join(f"<th>{_E(h)}</th>" for h in tab["headers"])
    width = len(tab["headers"])
    body_rows = "".join(
        "<tr>" + "".join(
            f"<td>{_E(str(c))}</td>" for c in (list(r) + [""] * width)[:width]
        ) + "</tr>"
        for r in tab["recent_rows"]
    )
    table = (
        f'<details class="table-fold"><summary>近 7 天明細</summary>'
        f"<table><thead><tr>{header_cells}</tr></thead><tbody>{body_rows}</tbody></table></details>"
    )
    return (
        f'<div class="metric-card"><div class="metric-head"><b>{_E(tab["name"])}</b>'
        f'<span>至 {_E(tab["latest_date"])}</span></div>'
        f'<div class="stats-row">{stats}{spark}</div>{table}</div>'
    )


_IG_POST_COLS = [
    ("posted_date", "發文日"), ("type", "類型"), ("caption", "貼文"),
    ("views", "views"), ("reach", "reach"), ("likes", "likes"),
    ("comments", "comments"), ("saved", "saved"), ("shares", "shares"),
    ("avg_watch_time", "平均觀看"),
]


def _ig_post_row(post: dict) -> str:
    cells = []
    for key, _ in _IG_POST_COLS:
        value = post.get(key, "")
        if key == "caption":
            text = value[:24] + "…" if len(value) > 24 else value or post.get("media_id", "")
            cells.append(f'<td><a href="{_E(post.get("permalink", ""))}">{_E(text)}</a></td>')
        elif key == "avg_watch_time":
            ms = _to_float(value)
            cells.append(f'<td class="num">{f"{ms / 1000:.1f}s" if ms is not None else "–"}</td>')
        elif key in ("posted_date", "type"):
            cells.append(f"<td>{_E(value)}</td>")
        else:
            cells.append(f'<td class="num">{_E(value) if value else "–"}</td>')
    return "<tr>" + "".join(cells) + "</tr>"


def _ig_posts_html(posts: list[dict], visible: int = 10) -> str:
    if not posts:
        return ""
    header = (
        "<thead><tr>"
        + "".join(f"<th>{_E(label)}</th>" for _, label in _IG_POST_COLS)
        + "</tr></thead>"
    )
    obs = max(p.get("obs_date", "") for p in posts)
    table = (
        f"<table>{header}<tbody>"
        + "".join(_ig_post_row(p) for p in posts[:visible])
        + "</tbody></table>"
    )
    fold = ""
    if len(posts) > visible:
        fold = (
            f'<details class="table-fold"><summary>更早的貼文（{len(posts) - visible}）</summary>'
            f"<table>{header}<tbody>"
            + "".join(_ig_post_row(p) for p in posts[visible:])
            + "</tbody></table></details>"
        )
    return (
        f'<div class="metric-card"><div class="metric-head"><b>IG 貼文成效</b>'
        f"<span>每貼文最新快照・至 {_E(obs)}</span></div>{table}{fold}</div>"
    )


_REEL_CHECKPOINTS = ["24h", "48h", "7d"]
_REEL_METRICS = [
    ("views", "views"), ("skip_rate_pct", "略過"), ("like_rate_pct", "按讚"),
]


def _reel_metric_cell(snapshot: dict | None, key: str) -> str:
    value = (snapshot or {}).get(key, "")
    if value == "":
        return '<td class="num">–</td>'
    text = f"{value}%" if key.endswith("_pct") else value
    return f'<td class="num">{_E(text)}</td>'


def _ig_reels_html(reels: list[dict]) -> str:
    if not reels:
        return ""
    top = (
        '<tr><th rowspan="2">發布日</th><th rowspan="2">Reel</th>'
        + "".join(
            f'<th colspan="{len(_REEL_METRICS)}">{cp}</th>'
            for cp in _REEL_CHECKPOINTS
        )
        + "</tr>"
    )
    sub = (
        "<tr>"
        + "".join(
            f"<th>{_E(label)}</th>"
            for _ in _REEL_CHECKPOINTS for _, label in _REEL_METRICS
        )
        + "</tr>"
    )
    rows = []
    for reel in reels:
        caption = reel.get("caption", "")
        text = caption[:24] + "…" if len(caption) > 24 else caption or reel.get("media_id", "")
        cells = "".join(
            _reel_metric_cell(reel["checkpoints"].get(cp), key)
            for cp in _REEL_CHECKPOINTS for key, _ in _REEL_METRICS
        )
        rows.append(
            f'<tr><td>{_E(reel.get("posted_date", ""))}</td>'
            f'<td><a href="{_E(reel.get("permalink", ""))}">{_E(text)}</a></td>'
            f"{cells}</tr>"
        )
    obs = max(
        (s.get("obs_date", "") for r in reels for s in r["checkpoints"].values()),
        default="",
    )
    return (
        f'<div class="metric-card"><div class="metric-head"><b>Reels 洞察快照</b>'
        f'<span>發布後 24h/48h/7d・至 {_E(obs)}・<a href="reels.html">完整明細 →</a></span></div>'
        f"<table><thead>{top}{sub}</thead><tbody>{''.join(rows)}</tbody></table></div>"
    )


_REEL_DETAIL_ROWS = [
    ("obs_date", "觀測日"),
    ("views", "觀看次數"), ("reach", "觸及帳號"),
    ("avg_watch_time_s", "平均觀看（秒）"), ("new_followers", "帶來粉絲"),
    ("skip_rate_pct", "略過率"), ("share_rate_pct", "分享率"),
    ("like_rate_pct", "按讚率"), ("save_rate_pct", "儲存率"),
    ("repost_rate_pct", "轉發率"), ("comment_rate_pct", "留言率"),
    ("src_reels_pct", "來源・Reels 頁籤"), ("src_explore_pct", "來源・探索"),
    ("src_feed_pct", "來源・動態消息"), ("src_profile_pct", "來源・個人檔案"),
    ("src_other_pct", "來源・其他"),
    ("profile_visits", "個人檔案瀏覽"), ("likes", "按讚數"), ("comments", "留言數"),
    ("reposts", "轉發次數"), ("shares", "分享次數"), ("saves", "儲存次數"),
    ("follower_pct", "觀眾・粉絲比"),
    ("age_13_17_pct", "年齡 13-17"), ("age_18_24_pct", "年齡 18-24"),
    ("age_25_34_pct", "年齡 25-34"), ("age_35_44_pct", "年齡 35-44"),
    ("age_45_54_pct", "年齡 45-54"), ("age_55_64_pct", "年齡 55-64"),
    ("age_65_plus_pct", "年齡 65+"),
    ("gender_male_pct", "性別・男"), ("gender_female_pct", "性別・女"),
    ("gender_other_pct", "性別・未指定"),
    # 國家分布仍由 metrics collector 收進 CSV，只是明細表暫不顯示
]


def _reel_detail_value(snapshot: dict | None, key: str) -> str:
    value = (snapshot or {}).get(key, "")
    if value == "":
        return "–"
    if key == "countries":
        return "、".join(
            f"{part.split(':', 1)[0]} {part.split(':', 1)[1]}%" if ":" in part else part
            for part in value.split("|")
        )
    return f"{value}%" if key.endswith("_pct") else value

def _reel_col_header(reel: dict) -> str:
    """一支 reel 一欄的表頭：發布日連到貼文，caption 放 title 提示。"""
    return (
        f'<th><a href="{_E(reel.get("permalink", ""))}" '
        f'title="{_E(reel.get("caption", "") or reel.get("media_id", ""))}">'
        f'{_E(reel.get("posted_date", ""))}</a></th>'
    )


def _place_from_caption(caption: str) -> str:
    """caption 格式為「hook  地點 · 時代  內文」，取第一個 · 之前、
    hook 之後的地點名當後備。"""
    head = caption.split(" · ", 1)[0]
    parts = [p for p in re.split(r"\s{2,}", head.strip()) if p]
    return parts[-1] if len(parts) >= 2 else ""


def _reel_place_map(data: dict) -> dict[str, str]:
    """由 reels_calendar collector 的 entries 建 發布日→景點 對照。"""
    entries = (data.get("reels") or {}).get("entries", [])
    return {e["date"]: e["place"] for e in entries if e.get("date") and e.get("place")}


def _reel_checkpoint_table(
    reels: list[dict], checkpoint: str, place_map: dict[str, str]
) -> str:
    """單一 checkpoint 的樞紐表：縱軸每支 reel（依發布日），橫軸各指標。"""
    entries = sorted(
        (r for r in reels if r["checkpoints"].get(checkpoint)),
        key=lambda r: r.get("posted_date", ""),
    )
    if not entries:
        return (
            '<div class="callout warn">這個時間點還沒有任何 reel 洞察快照。</div>'
        )
    # 只保留至少一支 reel 有值的指標欄（整欄皆空的略過）
    metrics = [
        (key, label)
        for key, label in _REEL_DETAIL_ROWS
        if any(
            _reel_detail_value(r["checkpoints"].get(checkpoint), key) != "–"
            for r in entries
        )
    ]
    head = (
        "<th>發布日</th><th>地點</th>"
        + "".join(f"<th>{_E(label)}</th>" for _, label in metrics)
    )
    rows = []
    for reel in entries:
        snapshot = reel["checkpoints"].get(checkpoint)
        date_cell = _reel_col_header(reel).replace("<th>", "<td>").replace("</th>", "</td>")
        place = (
            place_map.get(reel.get("posted_date", ""))
            or _place_from_caption(reel.get("caption", ""))
            or "–"
        )
        metric_cells = "".join(
            (
                f'<td class="num">{_E(v)}</td>'
                if (v := _reel_detail_value(snapshot, key)) == "–" or key != "countries"
                else f"<td>{_E(v)}</td>"
            )
            for key, _ in metrics
        )
        rows.append(f"<tr>{date_cell}<td>{_E(place)}</td>{metric_cells}</tr>")
    return (
        f'<div class="table-scroll"><table class="pivot">'
        f"<thead><tr>{head}</tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table></div>"
    )


_REELS_TAB_JS = """
document.querySelectorAll('.tabs button[data-cp]').forEach(btn=>{
  btn.addEventListener('click',()=>{
    const cp=btn.dataset.cp;
    document.querySelectorAll('.tabs button[data-cp]').forEach(
      b=>b.setAttribute('aria-selected', String(b===btn)));
    document.querySelectorAll('.panel[data-cp]').forEach(
      p=>p.classList.toggle('active', p.dataset.cp===cp));
  });
});
"""


def build_reels_html(data: dict) -> str:
    """獨立頁 out/reels.html：24h / 48h / 7d 三個 tab，各一張樞紐表
    （縱軸各指標，橫軸每支 reel 依發布日）。"""
    reels = (data.get("metrics") or {}).get("ig_reels", [])
    if reels:
        place_map = _reel_place_map(data)
        tabs = "".join(
            f'<button data-cp="{cp}"'
            f'{" aria-selected=\"true\"" if i == 0 else ""}>{cp}</button>'
            for i, cp in enumerate(_REEL_CHECKPOINTS)
        )
        panels = "".join(
            f'<div class="panel{" active" if i == 0 else ""}" data-cp="{cp}">'
            f"{_reel_checkpoint_table(reels, cp, place_map)}</div>"
            for i, cp in enumerate(_REEL_CHECKPOINTS)
        )
        body = f'<div class="tabs" role="tablist">{tabs}</div>{panels}'
    else:
        body = (
            '<div class="callout warn">還沒有 Reels 洞察快照——'
            "用 lorescape-metrics 記錄 24h/48h/7d 截圖後再看。</div>"
        )
    return f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lorescape Reels 洞察明細</title>
<style>{_CSS}</style>
</head>
<body>
<main>
<header><h1>REELS 洞察明細</h1>
<span class="stamp"><a href="index.html">← 回產品面板</a></span></header>
{body}
<footer>由 dashboard/ 工具產生・<code>uv run lorescape-dashboard</code></footer>
</main>
<script>{_REELS_TAB_JS}</script>
</body>
</html>"""


# ---------- 每日故事 ----------

_STORY_STATUS = {
    "published": ("good", "已發布"),
    "scheduled": ("warning", "已排程"),
    "pending": ("warning", "待審核"),
    "failed": ("critical", "失敗"),
    "rejected": ("critical", "已拒絕"),
    "skipped": ("muted", "略過"),
}


def _daily_story_html(story: dict) -> str:
    if not story["posts"]:
        return '<div class="callout error">今天還沒有 daily story 記錄</div>'
    chips = []
    for post in story["posts"]:
        level, label = _STORY_STATUS.get(post["status"], ("muted", post["status"]))
        detail = ""
        if post.get("published_at"):
            detail = f'　發布於 {post["published_at"][:16].replace("T", " ")} UTC'
        elif post.get("scheduled_at"):
            detail = f'　排程 {post["scheduled_at"][:16].replace("T", " ")} UTC'
        error = f'　<span class="status-critical">{_E(post["error"])}</span>' if post.get("error") else ""
        chips.append(
            f'<div class="chip"><i class="dot {level}"></i>'
            f'<b>{_E(post["media_type"])}</b>{_E(label)}{_E(detail)}{error}</div>'
        )
    return f'<div class="chips">{"".join(chips)}</div>'


# ---------- Reels 排程 ----------


def _reels_html(reels: dict, today: str) -> str:
    entries = reels["entries"]
    today_entry = next((e for e in entries if e["date"] == today), None)
    upcoming = [e for e in entries if e["date"] > today][:7]

    parts = []
    if today_entry:
        parts.append(
            f'<div class="callout"><b>今日景點：{_E(today_entry["place"])}</b>'
            f'（{_E(today_entry["category"])}）　'
            f'<span style="color:var(--muted)">DB 標題：{_E(today_entry["db_title"])}</span></div>'
        )
    elif entries:
        parts.append('<div class="callout warn">排程表沒有今天的景點（可能超出排程範圍）</div>')

    def rows(items: list[dict]) -> str:
        return "".join(
            f"<tr><td>{_E(e['date'])}</td><td>{_E(e['place'])}</td>"
            f"<td>{_E(e['category'])}</td><td>{_E(e['db_title'])}</td></tr>"
            for e in items
        )

    header = "<thead><tr><th>日期</th><th>景點</th><th>類型</th><th>DB 標題</th></tr></thead>"
    if upcoming:
        parts.append(f"<table>{header}<tbody>{rows(upcoming)}</tbody></table>")
    parts.append(
        f'<details class="table-fold"><summary>完整排程（{_E(reels["range"])}，'
        f"{len(entries)} 檔）</summary>"
        f"<table>{header}<tbody>{rows(entries)}</tbody></table></details>"
    )
    return "".join(parts)


# ---------- Scheduler 行程表 ----------

_WEEKDAY_NAMES = "一二三四五六日"


def _schedule_rows(items: list[dict], with_cadence: bool = False) -> str:
    return "".join(
        "<tr>"
        + (f'<td>{_E(i["cadence"])}</td>' if with_cadence else "")
        + f'<td>{_E(i["time"])}</td><td>{_E(_strip_md(i["task"]))}</td>'
        f'<td>{_E(_strip_md(i["command"]))}</td></tr>'
        for i in items
    )


def _cal_cell(d: date, month: int, schedule: dict, today: date) -> str:
    """單一日曆格：非當月為淡色空格；當月列日期與精簡標籤。"""
    if d.month != month:
        return '<div class="cal-day out"></div>'
    tags = []
    if schedule["daily"]:
        tags.append(f'<span class="cal-tag">● 每日 {len(schedule["daily"])}</span>')
    if d.weekday() == 0 and schedule["weekly"]:
        tags.append(f'<span class="cal-tag">▲ 週 {len(schedule["weekly"])}</span>')
    if d.day == 1 and schedule["monthly"]:
        tags.append(f'<span class="cal-tag">■ 月 {len(schedule["monthly"])}</span>')
    classes = "cal-day today selected" if d == today else "cal-day"
    return (
        f'<div class="{classes}" data-day="{d.isoformat()}">'
        f'<b>{d.day}</b>{"".join(tags)}</div>'
    )


def _cal_detail(d: date, schedule: dict, today: date) -> str:
    """單日明細（預先渲染、非今天隱藏，JS 點格子切換顯示）。"""
    header = (
        "<thead><tr><th>週期</th><th>時間</th><th>工作</th><th>指令 / skill</th></tr></thead>"
    )
    rows = _schedule_rows(compute_for_date(schedule, d), with_cadence=True)
    hidden = "" if d == today else " hidden"
    title = f"{d.month}/{d.day}（週{_WEEKDAY_NAMES[d.weekday()]}）"
    return (
        f'<div class="cal-detail" id="cal-detail-{d.isoformat()}"{hidden}>'
        f"<h3>{_E(title)} 待辦</h3><table>{header}<tbody>{rows}</tbody></table></div>"
    )


def _calendar_html(schedule: dict, today: date) -> str:
    weeks = calendar.Calendar().monthdatescalendar(today.year, today.month)
    head = "".join(f'<div class="cal-head">{w}</div>' for w in _WEEKDAY_NAMES)
    cells = "".join(
        _cal_cell(d, today.month, schedule, today) for week in weeks for d in week
    )
    details = "".join(
        _cal_detail(d, schedule, today)
        for week in weeks
        for d in week
        if d.month == today.month
    )
    legend = "● 每日　▲ 每週（週一）　■ 每月（1 號）　點日期看明細"
    return (
        f'<div class="callout"><b>{today.year} 年 {today.month} 月</b>　{_E(legend)}</div>'
        f'<div class="calendar">{head}{cells}</div>{details}'
    )


def _schedule_html(schedule: dict, today_str: str) -> str:
    try:
        today = date.fromisoformat(today_str)
    except ValueError:
        today = date.today()
    today_header = (
        "<thead><tr><th>週期</th><th>時間</th><th>工作</th><th>指令 / skill</th></tr></thead>"
    )
    return (
        '<div class="callout"><b>今日待辦</b></div>'
        f'<table>{today_header}<tbody>{_schedule_rows(schedule["today"], with_cadence=True)}</tbody></table>'
        + _calendar_html(schedule, today)
    )


# ---------- 組頁 ----------

# tab key → (tab 標籤, [(section key, section 標題)])
_TABS = [
    ("routine", "🗓 例行行程", [
        ("schedule", "🗓 Scheduler 行程表"),
    ]),
    ("progress", "📋 功能進度", [
        ("backlog", "📋 Backlog"),
    ]),
    ("dev", "🧪 開發現況", [
        ("tests", "🧪 自動化測試"),
        ("e2e", "🎯 E2E 測試案例"),
        ("deploys", "🚀 部署狀態"),
    ]),
    ("analytics", "📈 數據分析", [
        ("metrics", "📈 產品數據"),
    ]),
    ("story", "📅 每日故事", [
        ("daily_story", "📅 今日發布狀態"),
        ("reels", "🎬 Reels 選點排程"),
    ]),
]

_TAB_JS = """
const tabs=document.querySelectorAll('.tabs button');
function show(key){
  tabs.forEach(b=>b.setAttribute('aria-selected',b.dataset.tab===key));
  document.querySelectorAll('.panel').forEach(p=>p.classList.toggle('active',p.id==='tab-'+key));
}
tabs.forEach(b=>b.addEventListener('click',()=>{history.replaceState(null,'','#'+b.dataset.tab);show(b.dataset.tab);}));
const initial=location.hash.slice(1);
show([...tabs].some(b=>b.dataset.tab===initial)?initial:tabs[0].dataset.tab);
"""

# serve 模式（http 下才啟用）：區塊 ↻ 按鈕 + 每日故事/部署 60 秒自動刷新
_LIVE_JS = """
if(location.protocol==='http:'||location.protocol==='https:'){
  async function refreshSection(key,btn){
    if(btn){btn.disabled=true;btn.textContent='…';}
    try{
      const resp=await fetch('/api/section/'+key,{method:'POST'});
      if(resp.ok){document.getElementById('body-'+key).innerHTML=await resp.text();}
    }finally{if(btn){btn.disabled=false;btn.textContent='↻';}}
  }
  document.querySelectorAll('section').forEach(sec=>{
    const btn=document.createElement('button');
    btn.className='refresh';btn.textContent='↻';
    btn.title=sec.id==='tests'?'重跑三套測試（約 1–2 分鐘）':'重新收集這個區塊';
    btn.addEventListener('click',()=>refreshSection(sec.id,btn));
    sec.querySelector('h2').appendChild(btn);
  });
  setInterval(()=>{refreshSection('daily_story');refreshSection('deploys');},60000);
  // md-backed 區塊：輪詢來源檔 mtime，存檔後只刷新有變的那塊
  const WATCH=['backlog','schedule','reels'];
  let lastMtimes=null;
  async function pollMtimes(){
    try{
      const resp=await fetch('/api/mtimes');
      if(!resp.ok)return;
      const m=await resp.json();
      if(lastMtimes){
        for(const k of WATCH){
          if(m[k]&&m[k]!==lastMtimes[k])refreshSection(k);
        }
      }
      lastMtimes=m;
    }catch(e){}
  }
  setInterval(pollMtimes,2000);
}
"""

# 月曆點格子 → 切換該日明細；委派到 document，確保 serve 模式 ↻ 後仍可點
_CAL_JS = """
document.addEventListener('click',e=>{
  const cell=e.target.closest('.cal-day[data-day]');
  if(!cell)return;
  const sec=cell.closest('.sec-body');
  sec.querySelectorAll('.cal-day.selected').forEach(c=>c.classList.remove('selected'));
  cell.classList.add('selected');
  sec.querySelectorAll('.cal-detail').forEach(p=>p.hidden=p.id!=='cal-detail-'+cell.dataset.day);
});
"""


def section_body(key: str, data: dict) -> str:
    """單一區塊的內文 HTML（serve 模式的 ↻ 就地替換也用這個）。"""
    errors = data.get("errors", {})
    current_month = str(data.get("generated_at", ""))[:7]
    today = str(data.get("generated_at", ""))[:10]
    value = data.get(key)

    if value is None:
        body = _error_card(key, errors.get(key, "沒有資料（該 collector 未執行）"))
    elif key == "backlog":
        body = _epic_html(value) + _pending_html(value) + _kanban_html(value, current_month)
    elif key == "deploys":
        body = _deploys_html(value)
    elif key == "tests":
        body = _tests_html(value)
    elif key == "e2e":
        body = _e2e_html(value)
    elif key == "metrics":
        body = (
            "".join(_metric_card(t) for t in value["tabs"])
            + _ig_posts_html(value.get("ig_posts", []))
            + _ig_reels_html(value.get("ig_reels", []))
        )
    elif key == "daily_story":
        body = _daily_story_html(value)
    elif key == "reels":
        body = _reels_html(value, today)
    elif key == "schedule":
        body = _schedule_html(value, today)
    else:
        body = _error_card(key, "未知的區塊")

    stamp = data.get("collected_at", {}).get(key)
    if stamp:
        body = f'<div class="sec-stamp">資料時間：{_E(stamp)}</div>{body}'
    return body


def build_html(data: dict) -> str:
    def section(key: str, title: str) -> str:
        return (
            f'<section id="{key}"><h2><span class="hash">#</span>{_E(title)}</h2>'
            f'<div class="sec-body" id="body-{key}">{section_body(key, data)}</div></section>'
        )

    tab_buttons = "".join(
        f'<button role="tab" data-tab="{key}" aria-selected="false">{_E(label)}</button>'
        for key, label, _ in _TABS
    )
    panels = "".join(
        f'<div class="panel" id="tab-{key}" role="tabpanel">'
        + "".join(section(s_key, s_title) for s_key, s_title in sections)
        + "</div>"
        for key, _, sections in _TABS
    )

    return f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lorescape 產品面板</title>
<style>{_CSS}</style>
</head>
<body>
<main>
<header><h1>LORESCAPE 產品面板</h1>
<span class="stamp">最後更新：{_E(str(data.get("generated_at", "?")))}</span></header>
{_tiles(data)}
<div class="tabs" role="tablist">{tab_buttons}</div>
{panels}
<footer>由 dashboard/ 工具產生・<code>uv run lorescape-dashboard</code></footer>
</main>
<script>{_TAB_JS}{_LIVE_JS}{_CAL_JS}</script>
</body>
</html>"""
