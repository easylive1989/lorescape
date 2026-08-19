"""Free-tier usage policy.

The per-day free quota lives here (not in the database) so the limit is a
single application-owned constant. Premium users bypass this entirely.
"""
from __future__ import annotations

# Free narrations a non-subscriber may generate per calendar day.
DAILY_FREE_LIMIT = 1


def has_free_quota(used_today: int) -> bool:
    """True if a non-premium user may still generate today."""
    return used_today < DAILY_FREE_LIMIT
