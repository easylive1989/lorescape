"""Storage backends for the accumulating metrics datasets.

A store maps each :class:`DailySource` to one tab-shaped dataset (header row
plus data rows) and supports reading the existing keys and upserting fresh
rows. :class:`FileStore` persists to per-source CSVs under ``data/metrics/``
(the production source of truth, gitignored — the numbers include revenue
and the repo is public); :class:`MemoryStore` keeps data in-process for
tests. The legacy Google Sheet backend was removed 2026-07-11 after the
one-time export to CSVs.
"""
from __future__ import annotations

import csv
from pathlib import Path

from metrics._common import DailySource, key_width, merge_rows, row_key


class MetricsStore:
    """Read/upsert datasets keyed by a source's key column.

    Subclasses implement :meth:`read` and :meth:`_write`; the merge and key
    extraction are shared so every backend de-duplicates identically.
    """

    def read(self, source: DailySource) -> tuple[list[str], list[list[str]]]:
        """Return (headers, rows) currently stored for `source`."""
        raise NotImplementedError

    def _write(
        self, source: DailySource, headers: list[str], rows: list[list[str]]
    ) -> None:
        """Overwrite `source`'s dataset with the given headers and rows."""
        raise NotImplementedError

    def keys(self, source: DailySource) -> set:
        """Return the key values already stored for `source`.

        Each value is a single column or, for a composite `key_index`, the
        tuple of columns that identifies a row.
        """
        _, rows = self.read(source)
        ki = source.key_index
        width = key_width(ki)
        return {row_key(row, ki) for row in rows if len(row) > width}

    def upsert(
        self, source: DailySource, headers: list[str], new_rows: list[list[str]]
    ) -> int:
        """Merge `new_rows` into `source`'s dataset and persist the result.

        Returns how many rows actually changed the dataset — a key that was
        not stored before, or a stored key whose values differ. Rows that
        come back identical count zero, so callers report what was really
        written rather than what was fetched (sources like ``retention``
        re-compute a multi-day window every run and would otherwise look
        like they wrote rows when the file did not change).
        """
        _, existing = self.read(source)
        ki = source.key_index
        width = key_width(ki)
        before = {
            row_key(row, ki): row for row in existing if len(row) > width
        }
        changed = sum(
            1 for row in new_rows if before.get(row_key(row, ki)) != row
        )
        self._write(source, headers, merge_rows(
            existing, new_rows, ki, source.sort_index))
        return changed


class FileStore(MetricsStore):
    """Persist datasets to per-source CSV files in one directory.

    File name comes from ``DailySource.filename``; the first CSV row is the
    header. The directory lives in-repo (``data/metrics/``) but is
    gitignored — the numbers include revenue and the repo is public.
    """

    def __init__(self, directory: Path) -> None:
        self.directory = directory

    def _path(self, source: DailySource) -> Path:
        return self.directory / source.filename

    def read(self, source: DailySource) -> tuple[list[str], list[list[str]]]:
        path = self._path(source)
        if not path.exists():
            return [], []
        with path.open(newline="", encoding="utf-8") as f:
            values = list(csv.reader(f))
        if not values:
            return [], []
        return values[0], values[1:]

    def _write(
        self, source: DailySource, headers: list[str], rows: list[list[str]]
    ) -> None:
        self.directory.mkdir(parents=True, exist_ok=True)
        with self._path(source).open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerows([headers, *rows])


class MemoryStore(MetricsStore):
    """In-process store backed by a dict, for tests and dry experiments."""

    def __init__(self) -> None:
        self._data: dict[str, tuple[list[str], list[list[str]]]] = {}

    def seed(
        self, name: str, headers: list[str], rows: list[list[str]]
    ) -> None:
        """Pre-populate a source's dataset (test helper)."""
        self._data[name] = (headers, rows)

    def read(self, source: DailySource) -> tuple[list[str], list[list[str]]]:
        return self._data.get(source.name, ([], []))

    def _write(
        self, source: DailySource, headers: list[str], rows: list[list[str]]
    ) -> None:
        self._data[source.name] = (headers, rows)
