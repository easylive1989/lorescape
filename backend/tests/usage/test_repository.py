"""Tests for the Supabase-backed usage repository."""
from __future__ import annotations

from lorescape_backend.usage.repository import UsageRepository


class _FakeResponse:
    def __init__(self, data) -> None:
        self.data = data


class _FakeQuery:
    def __init__(self, response: _FakeResponse) -> None:
        self._response = response

    def execute(self) -> _FakeResponse:
        return self._response


class _FakeClient:
    def __init__(self, results: dict[str, object]) -> None:
        self._results = results
        self.calls: list[tuple[str, dict]] = []

    def rpc(self, name: str, params: dict) -> _FakeQuery:
        self.calls.append((name, params))
        return _FakeQuery(_FakeResponse(self._results.get(name)))


def test_used_today_reads_rpc_count():
    client = _FakeClient({"get_daily_used_count": 3})
    repo = UsageRepository(client)

    assert repo.used_today("user-1") == 3
    assert client.calls == [("get_daily_used_count", {"p_user_id": "user-1"})]


def test_used_today_defaults_to_zero_when_null():
    repo = UsageRepository(_FakeClient({"get_daily_used_count": None}))
    assert repo.used_today("user-1") == 0


def test_consume_increments_via_rpc_and_returns_new_count():
    client = _FakeClient({"consume_free_usage": 1})
    repo = UsageRepository(client)

    assert repo.consume("user-1") == 1
    assert client.calls == [("consume_free_usage", {"p_user_id": "user-1"})]
