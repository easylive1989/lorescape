# scripts/metrics/app_funnel.py
"""App 端漏斗階段（GA4），每日一列、一律以「人」為單位。

`narration.csv` 記的是 `eventCount`（同一個人可能重複播放），適合看完成率，
但拿來接在「下載」後面當漏斗階段會高估。本來源改用 `totalUsers`，讓
安裝 → 開啟 → 開始導覽 → 完成導覽 各階段都是人數，可以直接相除。

| 欄 | GA4 事件 | 意義 |
|---|---|---|
| `first_open_users` | `first_open` | 首次開啟 App 的人（≈ 安裝後真的打開的人） |
| `narration_start_users` | `narration_started` | 當天開始至少一段導覽的人 |
| `narration_complete_users` | `narration_completed` | 當天完成至少一段導覽的人 |

`first_open` 涵蓋 iOS + Android，而 `store_ios.csv` 的 downloads 只有 iOS
（Play 至今未匯出安裝數，見 BACKLOG F14）——兩者相除會高估開啟率，判讀時
要記得這個口徑差。
"""
from __future__ import annotations

from metrics._common import DailySource, MetricsConfig

# GA4 事件名 → CSV 欄名，依欄位順序
_EVENTS = {
    "first_open": "first_open_users",
    "narration_started": "narration_start_users",
    "narration_completed": "narration_complete_users",
}

_HEADERS = ["date", *_EVENTS.values()]


def _iso_date(ga4_date: str) -> str:
    """Convert GA4's ``YYYYMMDD`` date dimension to ISO ``YYYY-MM-DD``."""
    if len(ga4_date) == 8 and ga4_date.isdigit():
        return f"{ga4_date[:4]}-{ga4_date[4:6]}-{ga4_date[6:]}"
    return ga4_date


def parse_daily(resp: dict) -> dict[str, dict[str, str]]:
    """Map a date+eventName runReport into ``{date: {event: users}}``.

    Events outside `_EVENTS` are dropped — the report is not filtered
    server-side so one call covers all three stages.
    """
    out: dict[str, dict[str, str]] = {}
    for row in resp.get("rows", []):
        dims = [d.get("value", "") for d in row.get("dimensionValues", [])]
        mets = [m.get("value", "") for m in row.get("metricValues", [])]
        if len(dims) < 2:
            continue
        day, event = _iso_date(dims[0]), dims[1]
        if event not in _EVENTS or not day:
            continue
        out.setdefault(day, {})[event] = mets[0] if mets else ""
    return out


def to_rows(per_day: dict[str, dict[str, str]]) -> list[list[str]]:
    """Render the parsed map into wide per-day rows."""
    return [
        [day, *[per_day[day].get(event, "") for event in _EVENTS]]
        for day in sorted(per_day)
    ]


def _run_report(property_id: str, start: str, end: str) -> dict:
    """Call the GA4 Data API with date + eventName dimensions, user counts."""
    from google.analytics.data_v1beta import BetaAnalyticsDataClient
    from google.analytics.data_v1beta.types import (
        DateRange, Dimension, Metric, RunReportRequest,
    )
    from google.protobuf.json_format import MessageToDict

    client = BetaAnalyticsDataClient()
    request = RunReportRequest(
        property=f"properties/{property_id}",
        date_ranges=[DateRange(start_date=start, end_date=end)],
        dimensions=[Dimension(name="date"), Dimension(name="eventName")],
        metrics=[Metric(name="totalUsers")],
        limit=10000,
    )
    return MessageToDict(client.run_report(request)._pb)


def fetch_daily(cfg: MetricsConfig, start: str, end: str) -> list[list[str]]:
    """Return per-day user counts for each app funnel stage."""
    property_id = cfg.ga4_property_id_app or cfg.ga4_property_id_web
    return to_rows(parse_daily(_run_report(property_id, start, end)))


SOURCE = DailySource(
    name="app_funnel",
    filename="app_funnel.csv",
    headers=_HEADERS,
    required=("ga4_property_id_web", "ga4_property_id_app"),
    fetch=fetch_daily,
    ready=lambda cfg: bool(cfg.ga4_property_id_web or cfg.ga4_property_id_app),
)
