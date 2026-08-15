from __future__ import annotations

from metrics import report
from metrics._common import DailySource, MetricsConfig
from metrics.store import MemoryStore


def _demo_source(rows, required=("gsc_site_url",), keyed_by_date=True,
                 snapshot=False, refresh_days=None):
    return DailySource(
        name="demo",
        filename="demo.csv",
        headers=["date", "v"],
        required=required,
        fetch=lambda cfg, s, e: rows,
        keyed_by_date=keyed_by_date,
        snapshot=snapshot,
        refresh_days=refresh_days,
    )


READY = MetricsConfig(gsc_site_url="https://x")


def test_plan_window_returns_none_when_up_to_date():
    src = _demo_source([])
    store = MemoryStore()
    store.seed("demo", ["date", "v"], [["2026-06-23", "1"]])
    assert report.plan_window(src, store, "2026-06-23", 30, None) is None


def test_plan_window_backfills_gap():
    src = _demo_source([])
    store = MemoryStore()
    store.seed("demo", ["date", "v"], [["2026-06-21", "1"]])
    assert report.plan_window(src, store, "2026-06-23", 30, None) == (
        "2026-06-22", "2026-06-23"
    )


def test_plan_window_explicit_overrides():
    src = _demo_source([])
    assert report.plan_window(
        src, MemoryStore(), "2026-06-23", 30, ("2026-01-01", "2026-01-05")
    ) == ("2026-01-01", "2026-01-05")


def test_plan_window_media_keyed_uses_recent_window():
    src = _demo_source([], keyed_by_date=False)
    assert report.plan_window(src, MemoryStore(), "2026-06-23", 3, None) == (
        "2026-06-21", "2026-06-23"
    )


def test_plan_window_media_keyed_refresh_days_overrides_backfill():
    src = _demo_source([], keyed_by_date=False, refresh_days=7)
    # refresh_days wins over the run's backfill horizon (30 here).
    assert report.plan_window(src, MemoryStore(), "2026-06-23", 30, None) == (
        "2026-06-17", "2026-06-23"
    )


def test_plan_window_snapshot_targets_end_when_absent():
    src = _demo_source([], snapshot=True)
    assert report.plan_window(
        src, MemoryStore(), "2026-06-23", 30, None
    ) == ("2026-06-23", "2026-06-23")


def test_plan_window_snapshot_none_when_day_already_stored():
    src = _demo_source([], snapshot=True)
    store = MemoryStore()
    store.seed("demo", ["date", "v"], [["2026-06-23", "1"]])
    assert report.plan_window(src, store, "2026-06-23", 30, None) is None


def test_check_lines_snapshot_reports_pending_day():
    src = _demo_source([], snapshot=True)
    report.SOURCES["demo"] = src
    try:
        lines = report.check_lines(READY, ["demo"], "2026-06-23", MemoryStore())
    finally:
        report.SOURCES.pop("demo", None)
    assert "snapshot for 2026-06-23" in "\n".join(lines)


def test_accumulate_skips_when_not_ready():
    src = _demo_source([["2026-06-23", "1"]])
    r = report.accumulate(src, MetricsConfig(gsc_site_url=None),
                          "2026-06-23", MemoryStore())
    assert r.ok is False
    assert "missing config" in (r.skipped_reason or "")


def test_accumulate_upserts_into_store():
    src = _demo_source([["2026-06-23", "9"]])
    store = MemoryStore()
    r = report.accumulate(src, READY, "2026-06-23", store)
    assert r.ok is True and r.written == 1
    _, rows = store.read(src)
    assert rows == [["2026-06-23", "9"]]


def test_run_isolates_source_errors():
    def boom(cfg, s, e):
        raise RuntimeError("api down")

    src = DailySource(name="demo", filename="demo.csv", headers=["date", "v"],
                      required=("gsc_site_url",), fetch=boom)
    report.SOURCES["demo"] = src
    try:
        results = report.run(READY, ["demo"], "2026-06-23", MemoryStore())
    finally:
        report.SOURCES.pop("demo", None)
    assert results[0].ok is False
    assert "api down" in (results[0].skipped_reason or "")


def test_check_lines_reports_missing_config():
    cfg = MetricsConfig(gsc_site_url=None, ig_user_id="x",
                        meta_page_access_token="y")
    lines = report.check_lines(cfg, ["gsc", "ig"], "2026-06-23", MemoryStore())
    joined = "\n".join(lines)
    assert "gsc" in joined and "missing" in joined.lower()


def test_check_lines_reports_backfill_count():
    store = MemoryStore()
    store.seed("gsc", ["date", "clicks"], [["2026-06-21", "1"]])
    lines = report.check_lines(MetricsConfig(gsc_site_url="https://x"),
                               ["gsc"], "2026-06-23", store)
    assert "backfill 2 day(s)" in "\n".join(lines)


def test_check_lines_ga4_ready_with_only_app():
    cfg = MetricsConfig(ga4_property_id_web=None, ga4_property_id_app="123")
    lines = report.check_lines(cfg, ["ga4"], "2026-06-23", MemoryStore())
    assert "ga4: ready" in "\n".join(lines)


def test_check_lines_ga4_missing_when_neither():
    cfg = MetricsConfig(ga4_property_id_web=None, ga4_property_id_app=None)
    lines = report.check_lines(cfg, ["ga4"], "2026-06-23", MemoryStore())
    joined = "\n".join(lines)
    assert "GA4_PROPERTY_ID_WEB or GA4_PROPERTY_ID_APP" in joined


def test_main_check_does_not_write(monkeypatch, capsys):
    store = MemoryStore()
    monkeypatch.setattr(report, "build_store", lambda: store)
    rc = report.main(["--check", "--only", "gsc"])
    assert rc == 0
    assert store.read(report.SOURCES["gsc"]) == ([], [])
    assert "gsc" in capsys.readouterr().out


def test_format_results_renders_each_outcome():
    results = [
        report.AccumResult("gsc", ok=True, written=2,
                           window=("2026-06-22", "2026-06-23")),
        report.AccumResult("ga4", ok=True, note="up to date"),
        report.AccumResult("ig", ok=False, skipped_reason="missing config"),
    ]
    text = report.format_results(results)
    assert "gsc: +2 row(s)" in text
    assert "ga4: up to date" in text
    assert "ig: skipped — missing config" in text


def test_accumulate_reports_zero_when_refetched_rows_are_unchanged():
    """Re-fetching rows identical to the stored ones must not be reported as
    written. retention ignores the planned window and re-computes a 14-day
    span every run, so counting fetched rows made an unchanged file look
    like 10 freshly written rows."""
    src = _demo_source([["2026-06-22", "1"], ["2026-06-23", "9"]])
    store = MemoryStore()
    store.seed("demo", ["date", "v"],
               [["2026-06-22", "1"], ["2026-06-23", "9"]])
    r = report.accumulate(src, READY, "2026-06-25", store)
    assert r.ok is True
    assert r.written == 0


def test_accumulate_counts_rows_whose_values_changed():
    src = _demo_source([["2026-06-22", "1"], ["2026-06-23", "42"]])
    store = MemoryStore()
    store.seed("demo", ["date", "v"],
               [["2026-06-22", "1"], ["2026-06-23", "9"]])
    r = report.accumulate(src, READY, "2026-06-25", store)
    assert r.written == 1
