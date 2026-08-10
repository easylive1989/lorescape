# scripts/metrics/landing_cta.py
"""落地頁下載 CTA 點擊（GA4 `download_click` 事件），每日一列。

landing 的 `DownloadLink` 元件在點擊時送出 `download_click`，帶兩個參數：
`platform`（ios / android）與 `location`（hero / navbar / final_cta /
footer / story / place）。這是漏斗上「看到落地頁 → 想下載」那一段唯一的
量測點——GA4 從 2026-06 就在收，但直到 2026-08-10 才接進 metrics。

`click_users` 與 `clicks` 要分開看：漏斗要跟 `ga4.csv` 的 activeUsers 同為
「人」才可比，所以漏斗用 `click_users`；`clicks` 只當作點擊熱度的副指標
（同一個人可能點很多次）。

`platform` / `location` 需先在 GA4 註冊為自訂維度才查得到；未註冊時該欄留空
（不影響 `clicks` / `click_users` 兩欄）。
"""
from __future__ import annotations

from metrics._common import DailySource, MetricsConfig

_EVENT = "download_click"
_PLATFORMS = ("ios", "android")
_LOCATIONS = ("hero", "navbar", "final_cta", "footer", "story", "place")

_HEADERS = [
    "date", "click_users", "clicks",
    *[f"{p}_clicks" for p in _PLATFORMS],
    *[f"loc_{loc}" for loc in _LOCATIONS],
]


def _iso_date(ga4_date: str) -> str:
    """Convert GA4's ``YYYYMMDD`` date dimension to ISO ``YYYY-MM-DD``."""
    if len(ga4_date) == 8 and ga4_date.isdigit():
        return f"{ga4_date[:4]}-{ga4_date[4:6]}-{ga4_date[6:]}"
    return ga4_date


def parse_totals(resp: dict) -> dict[str, tuple[str, str]]:
    """``{date: (click_users, clicks)}`` from the date-only report."""
    out: dict[str, tuple[str, str]] = {}
    for row in resp.get("rows", []):
        dims = [d.get("value", "") for d in row.get("dimensionValues", [])]
        mets = [m.get("value", "") for m in row.get("metricValues", [])]
        if not dims:
            continue
        clicks = mets[0] if len(mets) > 0 else ""
        users = mets[1] if len(mets) > 1 else ""
        out[_iso_date(dims[0])] = (users, clicks)
    return out


def parse_breakdown(resp: dict) -> dict[str, dict[str, str]]:
    """``{date: {dimension_value: eventCount}}`` from a date+dimension report."""
    out: dict[str, dict[str, str]] = {}
    for row in resp.get("rows", []):
        dims = [d.get("value", "") for d in row.get("dimensionValues", [])]
        mets = [m.get("value", "") for m in row.get("metricValues", [])]
        if len(dims) < 2:
            continue
        day = _iso_date(dims[0])
        out.setdefault(day, {})[dims[1].strip().lower()] = mets[0] if mets else ""
    return out


def to_rows(
    totals: dict[str, tuple[str, str]],
    by_platform: dict[str, dict[str, str]],
    by_location: dict[str, dict[str, str]],
) -> list[list[str]]:
    """Render the three parsed reports into wide per-day rows."""
    rows: list[list[str]] = []
    for day in sorted(totals):
        users, clicks = totals[day]
        plat = by_platform.get(day, {})
        loc = by_location.get(day, {})
        rows.append([
            day, users, clicks,
            *[plat.get(p, "") for p in _PLATFORMS],
            *[loc.get(x, "") for x in _LOCATIONS],
        ])
    return rows


def _run_reports(property_id: str, start: str, end: str) -> tuple[dict, dict, dict]:
    """Three GA4 reports: totals, split by platform, split by location."""
    from google.analytics.data_v1beta import BetaAnalyticsDataClient
    from google.analytics.data_v1beta.types import (
        DateRange, Dimension, Filter, FilterExpression, Metric, RunReportRequest,
    )
    from google.protobuf.json_format import MessageToDict

    client = BetaAnalyticsDataClient()
    only_event = FilterExpression(
        filter=Filter(
            field_name="eventName",
            string_filter=Filter.StringFilter(value=_EVENT),
        )
    )

    def report(dimensions: list[str], metrics: list[str]) -> dict:
        request = RunReportRequest(
            property=f"properties/{property_id}",
            date_ranges=[DateRange(start_date=start, end_date=end)],
            dimensions=[Dimension(name=d) for d in dimensions],
            metrics=[Metric(name=m) for m in metrics],
            dimension_filter=only_event,
            limit=10000,
        )
        return MessageToDict(client.run_report(request)._pb)

    totals = report(["date"], ["eventCount", "totalUsers"])
    # 自訂維度未在 GA4 註冊時整份報表會失敗；此時只放棄拆分，保住總數
    try:
        platform = report(["date", "customEvent:platform"], ["eventCount"])
    except Exception:
        platform = {}
    try:
        location = report(["date", "customEvent:location"], ["eventCount"])
    except Exception:
        location = {}
    return totals, platform, location


def fetch_daily(cfg: MetricsConfig, start: str, end: str) -> list[list[str]]:
    """Return per-day download-CTA click rows for the window."""
    property_id = cfg.ga4_property_id_web or cfg.ga4_property_id_app
    totals, platform, location = _run_reports(property_id, start, end)
    return to_rows(parse_totals(totals), parse_breakdown(platform),
                   parse_breakdown(location))


SOURCE = DailySource(
    name="landing_cta",
    filename="landing_cta.csv",
    headers=_HEADERS,
    required=("ga4_property_id_web", "ga4_property_id_app"),
    fetch=fetch_daily,
    ready=lambda cfg: bool(cfg.ga4_property_id_web or cfg.ga4_property_id_app),
)
