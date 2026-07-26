"""Google Play source: daily installs + ratings from the reports bucket.

Play Console exports monthly stats CSVs into a per-developer GCS bucket
(`stats/installs/…` / `stats/ratings/…`, UTF-16), readable by the metrics
service account once granted in Play Console. Unlike App Store sales
reports the history is fully backfillable, but exports lag a couple of
days — absent tail days simply stay a gap for the next run.
"""
from __future__ import annotations

import csv
import io
from datetime import date

from metrics._common import DailySource, MetricsConfig

# Lorescape's Play package (frontend/android applicationId).
ANDROID_PACKAGE = "com.paulchwu.instantexplore"

_DAILY_HEADERS = [
    "date", "installs", "active_devices", "avg_rating_daily",
    "avg_rating_total", "store_listing_visitors",
    "store_listing_acquisitions",
]


def months_between(start: str, end: str) -> list[str]:
    """YYYYMM strings for every month the [start, end] window touches."""
    start_d, end_d = date.fromisoformat(start), date.fromisoformat(end)
    months: list[str] = []
    year, month = start_d.year, start_d.month
    while (year, month) <= (end_d.year, end_d.month):
        months.append(f"{year:04d}{month:02d}")
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)
    return months


def _column(header: list[str], name: str) -> int | None:
    return header.index(name) if name in header else None


def _parse_stat_csv(text: str, columns: tuple[str, ...],
                    blank: tuple[str, ...] = ("NA",)) -> dict[str, tuple]:
    """Map Date → the requested columns, blanking Play's NA markers."""
    rows = list(csv.reader(io.StringIO(text)))
    if len(rows) < 2:
        return {}
    header = rows[0]
    indexes = [_column(header, name) for name in columns]
    days: dict[str, tuple] = {}
    for row in rows[1:]:
        if not row or not row[0]:
            continue
        values = tuple(
            "" if i is None or len(row) <= i or row[i] in blank else row[i]
            for i in indexes
        )
        days[row[0]] = values
    return days


def parse_installs(text: str) -> dict[str, tuple]:
    """Date → (daily user installs, active device installs)."""
    return _parse_stat_csv(
        text, ("Daily User Installs", "Active Device Installs")
    )


def parse_ratings(text: str) -> dict[str, tuple]:
    """Date → (daily average rating, total average rating)."""
    return _parse_stat_csv(
        text, ("Daily Average Rating", "Total Average Rating")
    )


def parse_store_performance(text: str) -> dict[str, tuple[str, str]]:
    """Date → (store listing visitors, acquisitions), summed over the split.

    Unlike installs/ratings, Play never exports an ``overview`` for store
    performance — only dimension splits (country / traffic source). One
    date therefore spans several rows and the daily total is their sum.
    A CSV without these columns yields nothing rather than raising.
    """
    rows = list(csv.reader(io.StringIO(text)))
    if len(rows) < 2:
        return {}
    header = rows[0]
    visitors_i = _column(header, "Store listing visitors")
    acquisitions_i = _column(header, "Store listing acquisitions")
    if visitors_i is None or acquisitions_i is None:
        return {}
    totals: dict[str, list[int]] = {}
    for row in rows[1:]:
        if not row or not row[0]:
            continue
        day = totals.setdefault(row[0], [0, 0])
        for slot, index in ((0, visitors_i), (1, acquisitions_i)):
            if len(row) > index:
                try:
                    day[slot] += int(row[index])
                except ValueError:
                    continue
    return {
        day: (str(visitors), str(acquisitions))
        for day, (visitors, acquisitions) in totals.items()
    }


def _month_csv(cfg: MetricsConfig, kind: str, month: str,
               split: str = "overview") -> str | None:
    """Download one month's stats CSV, or None when not exported yet.

    Play writes the objects as UTF-16; the GCS JSON API needs the object
    name URL-encoded as a single path segment. ``split`` selects the
    dimension file — ``overview`` for installs/ratings, ``country`` for
    store performance, which Play only exports split.
    """
    from urllib.parse import quote

    import google.auth
    from google.auth.transport.requests import AuthorizedSession

    creds, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/devstorage.read_only"]
    )
    name = f"stats/{kind}/{kind}_{ANDROID_PACKAGE}_{month}_{split}.csv"
    resp = AuthorizedSession(creds).get(
        f"https://storage.googleapis.com/storage/v1/b/"
        f"{cfg.play_reports_bucket}/o/{quote(name, safe='')}",
        params={"alt": "media"},
        timeout=60,
    )
    if resp.status_code == 404:
        return None
    resp.raise_for_status()
    return resp.content.decode("utf-16")


def fetch_daily(cfg: MetricsConfig, start: str, end: str) -> list[list[str]]:
    """Return per-day install/rating rows over [start, end], keyed by date.

    A day produces a row as soon as *any* export mentions it — Play ships
    store performance long before it starts exporting installs/ratings for
    a new app, so those days would otherwise be lost. Days no export
    mentions yet (the ~2-day lag) stay missing and are picked up by a
    later run's gap-fill.
    """
    installs: dict[str, tuple] = {}
    ratings: dict[str, tuple] = {}
    performance: dict[str, tuple] = {}
    for month in months_between(start, end):
        installs_csv = _month_csv(cfg, "installs", month)
        if installs_csv is not None:
            installs.update(parse_installs(installs_csv))
        ratings_csv = _month_csv(cfg, "ratings", month)
        if ratings_csv is not None:
            ratings.update(parse_ratings(ratings_csv))
        performance_csv = _month_csv(
            cfg, "store_performance", month, split="country"
        )
        if performance_csv is not None:
            performance.update(parse_store_performance(performance_csv))
    rows: list[list[str]] = []
    for day in sorted(set(installs) | set(performance)):
        if not start <= day <= end:
            continue
        daily_installs, active = installs.get(day, ("", ""))
        rating_day, rating_total = ratings.get(day, ("", ""))
        visitors, acquisitions = performance.get(day, ("", ""))
        rows.append([
            day, daily_installs, active, rating_day, rating_total,
            visitors, acquisitions,
        ])
    return rows


SOURCE = DailySource(
    name="store_android",
    filename="store_android.csv",
    headers=_DAILY_HEADERS,
    required=("play_reports_bucket",),
    fetch=fetch_daily,
)
