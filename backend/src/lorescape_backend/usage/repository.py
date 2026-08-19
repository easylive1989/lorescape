"""Persistence for per-day free-usage counts, backed by Supabase RPCs."""
from __future__ import annotations


class UsageRepository:
    """Reads and increments ``daily_usage`` via SECURITY DEFINER RPCs.

    Constructed with a service-role Supabase client, so it bypasses RLS —
    this is server-only code.
    """

    def __init__(self, client) -> None:
        self._client = client

    def used_today(self, user_id: str) -> int:
        """Free narrations the user has already consumed today."""
        response = self._client.rpc(
            "get_daily_used_count", {"p_user_id": user_id}
        ).execute()
        return int(response.data or 0)

    def consume(self, user_id: str) -> int:
        """Atomically increment today's count and return the new value."""
        response = self._client.rpc(
            "consume_free_usage", {"p_user_id": user_id}
        ).execute()
        return int(response.data or 0)
