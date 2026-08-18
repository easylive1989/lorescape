# scripts/tests/test_store_ios_pages.py
from __future__ import annotations

from metrics import store_ios_pages

_HEADER = (
    "Date,App Name,App Apple Identifier,Event,Page Type,Source Type,"
    "Device,Territory,Counts,Unique Counts"
)


def _row(day: str, event: str, counts: str, territory: str = "TW") -> str:
    return f"{day},Lorescape,6751904060,{event},Product Page,App Store Search,iPhone,{territory},{counts},1"


def test_parse_engagement_sums_counts_across_dimension_rows():
    text = "\n".join([
        _HEADER,
        _row("2026-07-19", "Impression", "40"),
        _row("2026-07-19", "Impression", "10", territory="US"),
        _row("2026-07-19", "Product Page View", "12"),
        _row("2026-07-19", "Tap", "5"),  # other events are ignored
    ])
    assert store_ios_pages.parse_engagement(text) == {
        "2026-07-19": [50, 12],
    }


def test_parse_engagement_groups_by_date_and_reads_tsv():
    text = "\n".join([
        _HEADER.replace(",", "\t"),
        _row("2026-07-19", "Impressions", "7").replace(",", "\t"),
        _row("2026-07-20", "Page View", "3").replace(",", "\t"),
    ])
    assert store_ios_pages.parse_engagement(text) == {
        "2026-07-19": [7, 0],
        "2026-07-20": [0, 3],
    }


def test_parse_engagement_tolerates_empty_or_unknown_shape():
    assert store_ios_pages.parse_engagement("") == {}
    assert store_ios_pages.parse_engagement("foo,bar\n1,2") == {}


def _patch_network(monkeypatch, instances=None, segments=None,
                   request_id="req-1", report_id="rep-1"):
    """Stub the ASC helpers; `segments` maps instance id → text list."""
    segments = segments or {}
    monkeypatch.setattr(
        store_ios_pages, "_report_request_id", lambda cfg: request_id)
    monkeypatch.setattr(
        store_ios_pages, "_report_id", lambda cfg, rid: report_id)
    monkeypatch.setattr(
        store_ios_pages, "_daily_instances", lambda cfg, rid: instances or {})
    monkeypatch.setattr(
        store_ios_pages, "_instance_segments",
        lambda cfg, iid: iter(segments.get(iid, [])))


def _cfg():
    from metrics._common import MetricsConfig

    return MetricsConfig(
        asc_key_id="k", asc_issuer_id="i", asc_key_path="/tmp/x.p8",
    )


def test_fetch_daily_sums_an_instances_segments(monkeypatch):
    _patch_network(
        monkeypatch,
        instances={"2026-07-20": "i-20"},
        segments={
            # One instance's segments are partitions of the same window,
            # so their counts add up (40 + 10).
            "i-20": [
                "\n".join([_HEADER, _row("2026-07-19", "Impression", "40")]),
                "\n".join([
                    _HEADER,
                    _row("2026-07-19", "Impression", "10", territory="US"),
                    _row("2026-07-19", "Product Page View", "12"),
                ]),
            ],
        },
    )
    # Rows are keyed by the data's own Date, not the instance it arrived
    # in, so the 07-20 instance yields a 07-19 row and nothing for 07-20.
    rows = store_ios_pages.fetch_daily(_cfg(), "2026-07-18", "2026-07-21")
    assert rows == [["2026-07-19", "50", "12"]]


def test_fetch_daily_restates_days_repeated_across_instances(monkeypatch):
    _patch_network(
        monkeypatch,
        instances={"2026-07-20": "i-20", "2026-07-21": "i-21"},
        segments={
            # Each instance carries a rolling window; 07-19 appears in
            # both and must not be counted twice.
            "i-20": ["\n".join([
                _HEADER,
                _row("2026-07-18", "Impression", "8"),
                _row("2026-07-19", "Impression", "40"),
            ])],
            "i-21": ["\n".join([
                _HEADER,
                _row("2026-07-19", "Impression", "40"),
                _row("2026-07-20", "Impression", "5"),
            ])],
        },
    )
    rows = store_ios_pages.fetch_daily(_cfg(), "2026-07-18", "2026-07-21")
    assert rows == [
        ["2026-07-18", "8", "0"],
        ["2026-07-19", "40", "0"],
        ["2026-07-20", "5", "0"],
    ]


def test_fetch_daily_returns_nothing_until_request_and_report_exist(
        monkeypatch):
    _patch_network(monkeypatch, request_id=None)
    assert store_ios_pages.fetch_daily(_cfg(), "2026-07-19", "2026-07-20") == []

    _patch_network(monkeypatch, report_id=None)
    assert store_ios_pages.fetch_daily(_cfg(), "2026-07-19", "2026-07-20") == []


def test_source_is_registered_in_report():
    from metrics import report

    assert report.SOURCES["store_ios_pages"] is store_ios_pages.SOURCE


def test_source_descriptor_requires_asc_key_but_not_vendor_number():
    from metrics._common import MetricsConfig

    assert store_ios_pages.SOURCE.filename == "store_ios_pages.csv"
    assert store_ios_pages.SOURCE.missing_config(MetricsConfig()) == [
        "asc_key_id", "asc_issuer_id", "asc_key_path",
    ]
