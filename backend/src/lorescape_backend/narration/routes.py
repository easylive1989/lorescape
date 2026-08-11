"""FastAPI routes for on-demand narration."""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException

from lorescape_backend.auth import AuthedUser, require_user
from lorescape_backend.config import Config
from lorescape_backend.dependencies import get_config
from lorescape_backend.narration import service
from lorescape_backend.narration.cache import (
    HooksCacheRepository,
    NarrationCacheRepository,
    hook_id_for,
    place_key_for,
)
from lorescape_backend.narration.dependencies import (
    get_hooks_cache_repository,
    get_narration_cache_repository,
)
from lorescape_backend.narration.models import (
    HooksRequest,
    HooksResponse,
    NarrationRequest,
    NarrationResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/narration", tags=["narration"])


@router.post("/hooks", response_model=HooksResponse)
def post_hooks(
    request: HooksRequest,
    config: Config = Depends(get_config),
    user: AuthedUser = Depends(require_user),
    cache: HooksCacheRepository = Depends(get_hooks_cache_repository),
) -> HooksResponse:
    """Return 2-3 narrative angles for the given place.

    Results are cached per (place, language): the first asker pays the
    Gemini call, everyone after gets the stored hooks. Cache failures
    never break the endpoint — they just fall back to a fresh
    generation.
    """
    place_key = place_key_for(request)
    cached = cache.get(place_key, request.language)
    if cached is not None:
        return cached

    try:
        result = service.generate_hooks(
            settings=config.genai_settings,
            request=request,
            web_search=config.narration_web_search_enabled,
        )
    except service.UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    cache.put(place_key, request.language, result)
    return result


@router.post("", response_model=NarrationResponse)
def post_narration(
    request: NarrationRequest,
    config: Config = Depends(get_config),
    user: AuthedUser = Depends(require_user),
    cache: NarrationCacheRepository = Depends(get_narration_cache_repository),
) -> NarrationResponse:
    """Return the long-form 3-paragraph story for the given place.

    Free for every signed-in user: the subscription gate was
    temporarily removed (ADR 0006).

    Cached per (place, language, hook): the first asker pays the Gemini
    call, everyone choosing that same angle afterwards replays the same
    story. Cache failures never break the endpoint — they just fall back
    to a fresh generation.
    """
    place_key = place_key_for(request)
    hook_id = hook_id_for(request)
    cached = cache.get(place_key, request.language, hook_id)
    if cached is not None:
        return cached

    try:
        result = service.generate_narration(
            settings=config.genai_settings,
            request=request,
            web_search=config.narration_web_search_enabled,
        )
    except service.UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    cache.put(place_key, request.language, hook_id, result)
    return result
