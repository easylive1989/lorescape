"""App Store source: daily impressions + product page views (ASC Analytics).

Store-page funnel numbers (how many people saw the app on the App Store and
how many opened its product page) come from the asynchronous Analytics
Reports API: the app needs a one-off ONGOING report request, after which
Apple generates the "App Store Discovery and Engagement" report daily. The
first run only creates the request and writes nothing; instances start
appearing a day or two later and only cover dates from around the request
onward (ONGOING provides no deep history). Days whose instance Apple hasn't
produced yet simply yield no row and are retried by a later run's gap-fill;
days that will never get an instance (before the request existed) are
skipped the same way and stay blank.
"""
from __future__ import annotations

import csv
import gzip
from datetime import date, timedelta
from typing import Iterator

import requests

from metrics._asc import API as _ASC
from metrics._asc import token as _token
from metrics._common import DailySource, MetricsConfig
from metrics.store_ios import APPLE_APP_ID

# Apple split this report into Standard/Detailed variants; the bare name no
# longer matches anything, and filter[name] just returns nothing (no error),
# so a stale name here silently records 0 rows every run. Standard carries the
# impression / product-page-view totals this source needs.
REPORT_NAME = "App Store Discovery and Engagement Standard"

_DAILY_HEADERS = ["date", "impressions", "product_page_views"]

# Event-column values vary in number across Apple docs; normalize + match.
_IMPRESSION_EVENTS = frozenset({"impression", "impressions"})
_PAGE_VIEW_EVENTS = frozenset({
    "product page view", "product page views", "page view", "page views",
})


def _auth(cfg: MetricsConfig) -> dict[str, str]:
    return {"Authorization": f"Bearer {_token(cfg)}"}


def _paged(cfg: MetricsConfig, url: str,
           params: dict | None = None) -> Iterator[dict]:
    """Yield `data` items across all pages of an ASC list endpoint."""
    while url:
        resp = requests.get(url, headers=_auth(cfg), params=params,
                            timeout=60)
        resp.raise_for_status()
        payload = resp.json()
        yield from payload.get("data") or []
        url = (payload.get("links") or {}).get("next")
        params = None


def _report_request_id(cfg: MetricsConfig) -> str | None:
    """Return the app's active ONGOING report request, creating it once.

    ONGOING requests are stopped by Apple after long inactivity; a stopped
    one is deleted and replaced. Right after creation there are no reports
    yet, so None is returned and the run records nothing.
    """
    stopped: str | None = None
    for req in _paged(cfg, f"{_ASC}/apps/{APPLE_APP_ID}/analyticsReportRequests",
                      {"limit": 200}):
        attrs = req.get("attributes") or {}
        if attrs.get("accessType") != "ONGOING":
            continue
        if attrs.get("stoppedDueToInactivity"):
            stopped = req["id"]
            continue
        return req["id"]
    if stopped:
        requests.delete(f"{_ASC}/analyticsReportRequests/{stopped}",
                        headers=_auth(cfg), timeout=60)
    resp = requests.post(
        f"{_ASC}/analyticsReportRequests",
        headers=_auth(cfg),
        json={"data": {
            "type": "analyticsReportRequests",
            "attributes": {"accessType": "ONGOING"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": APPLE_APP_ID}},
            },
        }},
        timeout=60,
    )
    resp.raise_for_status()
    return None


def _report_id(cfg: MetricsConfig, request_id: str) -> str | None:
    """Find the discovery-and-engagement report under a report request."""
    for report in _paged(
        cfg, f"{_ASC}/analyticsReportRequests/{request_id}/reports",
        {"filter[name]": REPORT_NAME, "limit": 200},
    ):
        if (report.get("attributes") or {}).get("name") == REPORT_NAME:
            return report["id"]
    return None


def _daily_instances(cfg: MetricsConfig, report_id: str) -> dict[str, str]:
    """Map processingDate → instance id for the report's DAILY instances."""
    days: dict[str, str] = {}
    for inst in _paged(
        cfg, f"{_ASC}/analyticsReports/{report_id}/instances",
        {"filter[granularity]": "DAILY", "limit": 200},
    ):
        day = (inst.get("attributes") or {}).get("processingDate")
        if day:
            days[day] = inst["id"]
    return days


def _instance_segments(cfg: MetricsConfig,
                       instance_id: str) -> Iterator[str]:
    """Yield each segment of an instance as decompressed text.

    Segment URLs are pre-signed (no Authorization header) and gzipped.
    """
    for seg in _paged(
        cfg, f"{_ASC}/analyticsReportInstances/{instance_id}/segments"
    ):
        url = (seg.get("attributes") or {}).get("url")
        if not url:
            continue
        resp = requests.get(url, timeout=120)
        resp.raise_for_status()
        yield gzip.decompress(resp.content).decode("utf-8")


def parse_engagement(text: str) -> dict[str, list[int]]:
    """Sum impressions / product page views per date in one report segment.

    Rows are one per dimension combination (device, source type,
    territory…), so a day's total sums "Counts" across all rows of an
    event. "Unique Counts" de-duplicates only within a single dimension
    row — summing it would over-count — so unique figures are deliberately
    not collected. Handles both comma- and tab-delimited segments.
    """
    lines = text.splitlines()
    if not lines:
        return {}
    delimiter = "\t" if "\t" in lines[0] else ","
    rows = list(csv.reader(lines, delimiter=delimiter))
    header = rows[0]
    try:
        date_i = header.index("Date")
        event_i = header.index("Event")
        counts_i = header.index("Counts")
    except ValueError:
        return {}
    totals: dict[str, list[int]] = {}
    for row in rows[1:]:
        if len(row) <= max(date_i, event_i, counts_i):
            continue
        event = row[event_i].strip().lower()
        if event in _IMPRESSION_EVENTS:
            slot = 0
        elif event in _PAGE_VIEW_EVENTS:
            slot = 1
        else:
            continue
        try:
            count = int(float(row[counts_i]))
        except ValueError:
            continue
        totals.setdefault(row[date_i], [0, 0])[slot] += count
    return totals


def fetch_daily(cfg: MetricsConfig, start: str, end: str) -> list[list[str]]:
    """Return per-day impression/page-view rows over [start, end].

    An instance's processingDate is its *delivery* date, not the date of
    the data inside: each DAILY instance carries a rolling window of the
    few days before it (the 2026-08-17 instance holds 08-14…08-16). So
    rows are keyed by each segment row's own Date, never by the instance
    it arrived in. Overlapping days repeat identically across instances,
    so a later instance overwrites rather than adds to an earlier one —
    summing them would multiply every figure by the window width.

    Days no instance covers yet (the 1-day delivery lag, or days
    predating the ONGOING request) yield nothing and are picked up by a
    later run's gap-fill.
    """
    request_id = _report_request_id(cfg)
    if request_id is None:
        return []
    report_id = _report_id(cfg, request_id)
    if report_id is None:
        return []
    instances = _daily_instances(cfg, report_id)
    totals: dict[str, list[int]] = {}
    for _, instance_id in sorted(instances.items()):
        # An instance's segments are partitions of the same window, so they
        # add up; the finished window then replaces what an earlier
        # instance said about those days.
        window: dict[str, list[int]] = {}
        for segment in _instance_segments(cfg, instance_id):
            for seg_day, (imp, views) in parse_engagement(segment).items():
                slot = window.setdefault(seg_day, [0, 0])
                slot[0] += imp
                slot[1] += views
        totals.update(window)
    rows: list[list[str]] = []
    cursor = date.fromisoformat(start)
    last = date.fromisoformat(end)
    while cursor <= last:
        day = cursor.isoformat()
        if day in totals:
            impressions, page_views = totals[day]
            rows.append([day, str(impressions), str(page_views)])
        cursor += timedelta(days=1)
    return rows


SOURCE = DailySource(
    name="store_ios_pages",
    filename="store_ios_pages.csv",
    headers=_DAILY_HEADERS,
    required=("asc_key_id", "asc_issuer_id", "asc_key_path"),
    fetch=fetch_daily,
)
