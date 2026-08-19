"""Tests for the free-usage policy."""
from __future__ import annotations

from lorescape_backend.usage.policy import DAILY_FREE_LIMIT, has_free_quota


def test_quota_available_below_limit():
    assert has_free_quota(0) is True


def test_quota_exhausted_at_limit():
    assert has_free_quota(DAILY_FREE_LIMIT) is False


def test_quota_exhausted_above_limit():
    assert has_free_quota(DAILY_FREE_LIMIT + 5) is False
