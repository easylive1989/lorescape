"""Accumulate metrics sources into per-source CSVs under ``data/metrics/``.

Each source is upserted into a same-named CSV (``gsc.csv`` / ``ga4.csv`` /
``ig.csv`` / ``ig_posts.csv``…), keyed by date (or media id). A run targets
yesterday and backfills any missing days since the last record, so each file
grows one row per day over time. The CSVs are the source of truth — gap
detection reads them back. The directory is in-repo but gitignored (the
numbers include revenue and the repo is public).
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

from dotenv import load_dotenv

from metrics._common import (
    REPO_ROOT,
    DailySource,
    MetricsConfig,
    date_range,
    missing_days,
)
from metrics.app_funnel import SOURCE as APP_FUNNEL_SOURCE
from metrics.ga4 import SOURCE as GA4_SOURCE
from metrics.gsc import SOURCE as GSC_SOURCE
from metrics.ig import SOURCE as IG_SOURCE
from metrics.ig_posts import SOURCE as IG_POSTS_SOURCE
from metrics.landing_cta import SOURCE as LANDING_CTA_SOURCE
from metrics.narration import SOURCE as NARRATION_SOURCE
from metrics.retention import SOURCE as RETENTION_SOURCE
from metrics.revenuecat import SOURCE as REVENUECAT_SOURCE
from metrics.store import FileStore, MetricsStore
from metrics.store_android import SOURCE as STORE_ANDROID_SOURCE
from metrics.store_ios import SOURCE as STORE_IOS_SOURCE
from metrics.store_ios_pages import SOURCE as STORE_IOS_PAGES_SOURCE

DEFAULT_BACKFILL = 30
DATA_DIR = REPO_ROOT / "data" / "metrics"

SOURCES: dict[str, DailySource] = {
    source.name: source
    for source in (
        GSC_SOURCE, GA4_SOURCE, LANDING_CTA_SOURCE, IG_SOURCE, IG_POSTS_SOURCE,
        NARRATION_SOURCE, APP_FUNNEL_SOURCE,
        RETENTION_SOURCE, REVENUECAT_SOURCE, STORE_ANDROID_SOURCE,
        STORE_IOS_SOURCE, STORE_IOS_PAGES_SOURCE,
    )
}


@dataclass
class AccumResult:
    """Outcome of accumulating one source for a run."""

    name: str
    ok: bool
    written: int = 0
    window: tuple[str, str] | None = None
    skipped_reason: str | None = None
    note: str | None = None


def _repo_root() -> Path:
    return REPO_ROOT


def _default_end() -> str:
    """Yesterday in ISO — the latest day with complete data."""
    _, end = date_range(days=1)
    return end


def missing_note(source: DailySource, cfg: MetricsConfig) -> str:
    """Human-readable reason a source can't run for lack of config."""
    if source.name == "ga4":
        return "missing config → GA4_PROPERTY_ID_WEB or GA4_PROPERTY_ID_APP"
    return "missing config → " + ", ".join(source.missing_config(cfg))


def plan_window(
    source: DailySource,
    store: MetricsStore,
    end: str,
    backfill: int,
    explicit: tuple[str, str] | None,
) -> tuple[str, str] | None:
    """Return the (start, end) to fetch, or None if already up to date.

    Date-keyed sources fetch only the gap up to `end`; media-keyed sources
    always refresh their recent window (`refresh_days`, else `backfill`);
    snapshot sources record a single live reading for `end` unless that day
    is already stored. An explicit window overrides all of these for manual
    backfills.
    """
    if explicit is not None:
        return explicit
    if source.snapshot:
        return None if end in store.keys(source) else (end, end)
    if source.keyed_by_date:
        days = missing_days(store.keys(source), end, backfill)
        return (days[0], days[-1]) if days else None
    lookback = source.refresh_days or backfill
    start = (date.fromisoformat(end) - timedelta(days=lookback - 1)).isoformat()
    return start, end


def accumulate(
    source: DailySource,
    cfg: MetricsConfig,
    end: str,
    store: MetricsStore,
    backfill: int = DEFAULT_BACKFILL,
    explicit: tuple[str, str] | None = None,
) -> AccumResult:
    """Fetch a source's pending window and upsert it into its sheet tab."""
    if not source.is_ready(cfg):
        return AccumResult(source.name, ok=False,
                           skipped_reason=missing_note(source, cfg))
    window = plan_window(source, store, end, backfill, explicit)
    if window is None:
        return AccumResult(source.name, ok=True, note="up to date")
    rows = source.fetch(cfg, window[0], window[1])
    written = store.upsert(source, source.headers, rows)
    return AccumResult(source.name, ok=True, written=written, window=window)


def run(
    cfg: MetricsConfig,
    names: list[str],
    end: str,
    store: MetricsStore,
    backfill: int = DEFAULT_BACKFILL,
    explicit: tuple[str, str] | None = None,
) -> list[AccumResult]:
    """Accumulate each named source, isolating per-source failures."""
    results: list[AccumResult] = []
    for name in names:
        source = SOURCES.get(name)
        if source is None:
            results.append(
                AccumResult(name, ok=False, skipped_reason="unknown source")
            )
            continue
        try:
            results.append(
                accumulate(source, cfg, end, store, backfill, explicit)
            )
        except Exception as exc:  # isolate per-source failures
            results.append(
                AccumResult(name, ok=False, skipped_reason=f"error: {exc}")
            )
    return results


def check_lines(
    cfg: MetricsConfig,
    names: list[str],
    end: str,
    store: MetricsStore,
    backfill: int = DEFAULT_BACKFILL,
) -> list[str]:
    """One readiness line per source; reads the store to size the gap."""
    lines: list[str] = []
    for name in names:
        source = SOURCES.get(name)
        if source is None:
            lines.append(f"- {name}: unknown source")
            continue
        if not source.is_ready(cfg):
            lines.append(f"- {name}: {missing_note(source, cfg)}")
            continue
        keys = store.keys(source)
        if source.snapshot:
            latest = max(keys) if keys else "empty"
            if end in keys:
                lines.append(f"- {name}: ready, up to date (last {latest})")
            else:
                lines.append(f"- {name}: ready, snapshot for {end} "
                             f"(last {latest})")
        elif source.keyed_by_date:
            days = missing_days(keys, end, backfill)
            latest = max(keys) if keys else "empty"
            if not days:
                lines.append(f"- {name}: ready, up to date (last {latest})")
            else:
                lines.append(
                    f"- {name}: ready, last {latest}, "
                    f"backfill {len(days)} day(s) → {end}"
                )
        else:
            lookback = source.refresh_days or backfill
            start = (date.fromisoformat(end)
                     - timedelta(days=lookback - 1)).isoformat()
            lines.append(
                f"- {name}: ready, track posts published {start} → {end}, "
                f"+1 obs/post ({len(keys)} row(s) stored)"
            )
    return lines


def format_results(results: list[AccumResult]) -> str:
    """Render run outcomes for the console."""
    out: list[str] = []
    for r in results:
        if not r.ok:
            out.append(f"- {r.name}: skipped — {r.skipped_reason}")
        elif r.note:
            out.append(f"- {r.name}: {r.note}")
        elif r.window is not None:
            start, end = r.window
            out.append(f"- {r.name}: +{r.written} row(s) for {start} → {end}")
        else:
            out.append(f"- {r.name}: {r.written} row(s)")
    return "\n".join(out)


def build_store() -> FileStore:
    """Build the CSV file store under ``data/metrics/``."""
    return FileStore(DATA_DIR)


def main(argv: list[str] | None = None) -> int:
    load_dotenv(_repo_root() / "scripts" / ".env")
    parser = argparse.ArgumentParser(
        description="Accumulate Lorescape metrics into data/metrics/ CSVs."
    )
    parser.add_argument(
        "--days", type=int, default=DEFAULT_BACKFILL,
        help="backfill horizon when seeding / posts refresh window",
    )
    parser.add_argument("--start", help="force an explicit backfill start")
    parser.add_argument("--end", help="target end date (default: yesterday)")
    parser.add_argument("--only", help="comma-separated subset of sources")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    cfg = MetricsConfig.from_env()
    names = (
        [s.strip() for s in args.only.split(",")]
        if args.only else list(SOURCES.keys())
    )
    end = args.end or _default_end()
    explicit = (args.start, end) if args.start else None
    store = build_store()

    if args.check:
        print(f"target end: {end}")
        print("\n".join(check_lines(cfg, names, end, store, args.days)))
        return 0

    results = run(cfg, names, end, store, args.days, explicit)
    print(f"data dir: {store.directory}")
    print(format_results(results))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
