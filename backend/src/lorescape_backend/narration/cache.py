"""Persistent caches for the /narration endpoints.

Hooks are free + unlimited, and every cold generation costs a grounded
Gemini call, so the first asker of a (place, language) pair pays the
cost and everyone after reads this Supabase-backed cache. The long-form
narration is cached the same way, keyed additionally by the chosen hook
so each narrative angle keeps its own story.

Failure policy: the caches must never break the endpoints. Both reads
and writes swallow exceptions (logged) and the routes fall back to a
fresh generation. Only successful, non-empty results are stored — a
place that failed once (insufficient_source) can succeed later.
"""
from __future__ import annotations

import logging

from lorescape_backend.narration.models import (
    HookItem,
    HooksRequest,
    HooksResponse,
    NarrationRequest,
    NarrationResponse,
)

logger = logging.getLogger(__name__)

_TABLE = "narration_hooks_cache"
_NARRATION_TABLE = "narration_cache"


def place_key_for(request: HooksRequest | NarrationRequest) -> str:
    """Stable cache key: Q-id, or a title-prefixed key on the legacy path."""
    if request.wikidata_id:
        return request.wikidata_id
    return f"title:{request.wikipedia_title}"


def hook_id_for(request: NarrationRequest) -> str:
    """Key part for the chosen angle; '' when generated without a hook."""
    return request.hook.id if request.hook else ""


class HooksCacheRepository:
    """Reads/writes the ``narration_hooks_cache`` table (service role)."""

    def __init__(self, client) -> None:
        self._client = client

    def get(self, place_key: str, language: str) -> HooksResponse | None:
        """Cached response for the pair, or None on miss/any error."""
        try:
            response = (
                self._client.table(_TABLE)
                .select("hooks")
                .eq("place_key", place_key)
                .eq("language", language)
                .limit(1)
                .execute()
            )
            rows = response.data or []
            if not rows:
                return None
            hooks = [HookItem(**item) for item in rows[0]["hooks"]]
        except Exception as exc:  # noqa: BLE001 — cache must never break the API
            logger.warning(
                "narration.hooks_cache.read_failed",
                extra={"place_key": place_key, "err": str(exc)},
            )
            return None
        logger.info(
            "narration.hooks_cache.hit", extra={"place_key": place_key},
        )
        return HooksResponse(hooks=hooks, insufficient_source=False)

    def put(
        self, place_key: str, language: str, result: HooksResponse
    ) -> None:
        """Store a successful result; skips empty/insufficient ones."""
        if result.insufficient_source or not result.hooks:
            return
        try:
            self._client.table(_TABLE).upsert(
                {
                    "place_key": place_key,
                    "language": language,
                    "hooks": [hook.model_dump() for hook in result.hooks],
                }
            ).execute()
        except Exception as exc:  # noqa: BLE001 — cache must never break the API
            logger.warning(
                "narration.hooks_cache.write_failed",
                extra={"place_key": place_key, "err": str(exc)},
            )


class NarrationCacheRepository:
    """Reads/writes the ``narration_cache`` table (service role)."""

    def __init__(self, client) -> None:
        self._client = client

    def get(
        self, place_key: str, language: str, hook_id: str
    ) -> NarrationResponse | None:
        """Cached story for the triple, or None on miss/any error."""
        try:
            response = (
                self._client.table(_NARRATION_TABLE)
                .select("narration")
                .eq("place_key", place_key)
                .eq("language", language)
                .eq("hook_id", hook_id)
                .limit(1)
                .execute()
            )
            rows = response.data or []
            if not rows:
                return None
            narration = NarrationResponse(**rows[0]["narration"])
        except Exception as exc:  # noqa: BLE001 — cache must never break the API
            logger.warning(
                "narration.cache.read_failed",
                extra={
                    "place_key": place_key,
                    "hook_id": hook_id,
                    "err": str(exc),
                },
            )
            return None
        logger.info(
            "narration.cache.hit",
            extra={"place_key": place_key, "hook_id": hook_id},
        )
        return narration

    def put(
        self,
        place_key: str,
        language: str,
        hook_id: str,
        result: NarrationResponse,
    ) -> None:
        """Store a successful story; skips empty/insufficient ones."""
        if result.insufficient_source or not result.paragraphs:
            return
        try:
            self._client.table(_NARRATION_TABLE).upsert(
                {
                    "place_key": place_key,
                    "language": language,
                    "hook_id": hook_id,
                    "narration": result.model_dump(),
                }
            ).execute()
        except Exception as exc:  # noqa: BLE001 — cache must never break the API
            logger.warning(
                "narration.cache.write_failed",
                extra={
                    "place_key": place_key,
                    "hook_id": hook_id,
                    "err": str(exc),
                },
            )
