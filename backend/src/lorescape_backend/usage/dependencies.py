"""FastAPI dependencies for the usage feature."""
from __future__ import annotations

from fastapi import Depends
from supabase import Client

from lorescape_backend.dependencies import get_supabase_client
from lorescape_backend.usage.repository import UsageRepository


def get_usage_repository(
    client: Client = Depends(get_supabase_client),
) -> UsageRepository:
    """FastAPI dependency providing the repository — overridden in tests."""
    return UsageRepository(client)
