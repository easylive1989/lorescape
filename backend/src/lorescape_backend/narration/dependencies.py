"""FastAPI dependencies for the narration feature."""
from __future__ import annotations

from fastapi import Depends
from supabase import Client

from lorescape_backend.dependencies import get_supabase_client
from lorescape_backend.narration.cache import (
    HooksCacheRepository,
    NarrationCacheRepository,
)


def get_hooks_cache_repository(
    client: Client = Depends(get_supabase_client),
) -> HooksCacheRepository:
    """FastAPI dependency providing the repository — overridden in tests."""
    return HooksCacheRepository(client)


def get_narration_cache_repository(
    client: Client = Depends(get_supabase_client),
) -> NarrationCacheRepository:
    """FastAPI dependency providing the repository — overridden in tests."""
    return NarrationCacheRepository(client)
