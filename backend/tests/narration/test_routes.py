from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from lorescape_backend.auth import AuthedUser, get_token_verifier, require_user
from lorescape_backend.config import Config
from lorescape_backend.narration.cache import NarrationCacheRepository
from lorescape_backend.narration.models import (
    HookItem,
    HooksResponse,
    NarrationResponse,
)
from lorescape_backend.narration.dependencies import (
    get_hooks_cache_repository,
    get_narration_cache_repository,
)
from lorescape_backend.narration.routes import get_config, router
from lorescape_backend.narration.service import UnsupportedLanguageError
from lorescape_backend.subscriptions.dependencies import (
    get_subscription_checker,
)
from lorescape_backend.usage.dependencies import get_usage_repository


def _fake_config() -> Config:
    return Config(
        supabase_url="x",
        supabase_service_role_key="x",
        gemini_api_key="test-key",
        revenuecat_webhook_auth_token=None,
        revenuecat_api_key=None,
    )


class _FakeHooksCache:
    """In-memory stand-in for HooksCacheRepository."""

    def __init__(self) -> None:
        self.store: dict[tuple[str, str], HooksResponse] = {}
        self.put_calls: int = 0

    def get(self, place_key: str, language: str) -> HooksResponse | None:
        return self.store.get((place_key, language))

    def put(self, place_key: str, language: str, result: HooksResponse) -> None:
        self.put_calls += 1
        if result.insufficient_source or not result.hooks:
            return
        self.store[(place_key, language)] = result


class _FakeNarrationCache:
    """In-memory stand-in for NarrationCacheRepository."""

    def __init__(self) -> None:
        self.store: dict[tuple[str, str, str], NarrationResponse] = {}

    def get(
        self, place_key: str, language: str, hook_id: str
    ) -> NarrationResponse | None:
        return self.store.get((place_key, language, hook_id))

    def put(
        self,
        place_key: str,
        language: str,
        hook_id: str,
        result: NarrationResponse,
    ) -> None:
        if result.insufficient_source or not result.paragraphs:
            return
        self.store[(place_key, language, hook_id)] = result


class _FakeSubscriptions:
    """In-memory stand-in for SubscriptionChecker (same `is_subscribed` shape)."""

    def __init__(self, premium: bool = False) -> None:
        self.premium = premium

    def is_subscribed(self, user_id: str) -> bool:
        return self.premium


class _FakeUsage:
    """In-memory stand-in for UsageRepository."""

    def __init__(self, used: int = 0) -> None:
        self.used = used
        self.consumed = 0

    def used_today(self, user_id: str) -> int:
        return self.used

    def consume(self, user_id: str) -> int:
        self.consumed += 1
        self.used += 1
        return self.used


def _make_app(
    hooks_cache: _FakeHooksCache | None = None,
    narration_cache: _FakeNarrationCache | None = None,
    subscriptions: _FakeSubscriptions | None = None,
    usage: _FakeUsage | None = None,
) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_config] = _fake_config
    app.dependency_overrides[require_user] = lambda: AuthedUser(
        user_id="user-1", is_anonymous=False
    )
    app.dependency_overrides[get_hooks_cache_repository] = (
        lambda: hooks_cache if hooks_cache is not None else _FakeHooksCache()
    )
    app.dependency_overrides[get_narration_cache_repository] = (
        lambda: narration_cache
        if narration_cache is not None
        else _FakeNarrationCache()
    )
    app.dependency_overrides[get_subscription_checker] = (
        lambda: subscriptions
        if subscriptions is not None
        else _FakeSubscriptions()
    )
    app.dependency_overrides[get_usage_repository] = (
        lambda: usage if usage is not None else _FakeUsage()
    )
    return app



@patch("lorescape_backend.narration.routes.service.generate_hooks")
def test_post_hooks_returns_payload(gen_hooks):
    gen_hooks.return_value = HooksResponse(
        hooks=[HookItem(id="h1", title="T1", teaser="Te1")],
        insufficient_source=False,
    )
    client = TestClient(_make_app())

    response = client.post(
        "/narration/hooks",
        json={
            "place_name": "Arles",
            "location": "Provence",
            "wikipedia_title": "Arles",
            "language": "zh-TW",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["hooks"][0]["id"] == "h1"
    assert body["insufficient_source"] is False
    # The route MUST pass the backend settings from config to the service.
    assert gen_hooks.call_args.kwargs["settings"] == _fake_config().genai_settings


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_post_narration_returns_payload(gen_narration):
    gen_narration.return_value = NarrationResponse(
        place_name="亞爾",
        location="法國普羅旺斯",
        era="十九世紀末",
        paragraphs=["一", "二", "三"],
        pull_quote="",
        insufficient_source=False,
    )
    client = TestClient(_make_app())

    response = client.post(
        "/narration",
        json={
            "place_name": "Arles",
            "location": "Provence",
            "wikipedia_title": "Arles",
            "language": "zh-TW",
            "hook": {"id": "h", "title": "梵谷", "teaser": "444 天"},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["place_name"] == "亞爾"
    assert body["paragraphs"] == ["一", "二", "三"]
    assert body["insufficient_source"] is False


def test_post_hooks_rejects_unsupported_language():
    client = TestClient(_make_app())
    response = client.post(
        "/narration/hooks",
        json={
            "place_name": "x",
            "wikipedia_title": "x",
            "language": "ja",
        },
    )
    assert response.status_code == 400


def test_post_narration_rejects_unsupported_language():
    client = TestClient(_make_app())
    response = client.post(
        "/narration",
        json={
            "place_name": "x",
            "wikipedia_title": "x",
            "language": "ja",
        },
    )
    assert response.status_code == 400


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_route_accepts_wikidata_id(gen_narration):
    gen_narration.return_value = NarrationResponse(
        place_name="Test",
        location="Somewhere",
        era="modern",
        paragraphs=["a", "a", "a"],
        pull_quote="x",
        insufficient_source=False,
    )
    client = TestClient(_make_app())

    res = client.post(
        "/narration",
        json={
            "wikidata_id": "Q1",
            "place_name": "Test",
            "location": "Somewhere",
            "language": "en",
        },
    )
    assert res.status_code == 200


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_route_accepts_legacy_wikipedia_title(gen_narration):
    gen_narration.return_value = NarrationResponse(
        place_name="Macaron Park",
        location="Taoyuan",
        era="modern",
        paragraphs=["a", "a", "a"],
        pull_quote="x",
        insufficient_source=False,
    )
    client = TestClient(_make_app())

    res = client.post(
        "/narration",
        json={
            "wikipedia_title": "Macaron Park",
            "place_name": "Macaron Park",
            "location": "Taoyuan",
            "language": "en",
        },
    )
    assert res.status_code == 200


def test_narration_route_400_when_no_identity_provided():
    client = TestClient(_make_app())
    res = client.post(
        "/narration",
        json={
            "place_name": "x",
            "location": "y",
            "language": "en",
        },
    )
    assert res.status_code in (400, 422)


class _NeverVerifier:
    """Token verifier that fails the test if ever consulted."""

    def verify(self, token: str):  # pragma: no cover - must not run
        raise AssertionError("verifier should not run without a token")


def test_narration_route_401_without_bearer_token():
    # An app WITHOUT a require_user override behaves like production: a
    # request carrying no Authorization header is rejected up front, before
    # the token verifier (which would hit Supabase) is ever consulted.
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_config] = _fake_config
    app.dependency_overrides[get_token_verifier] = lambda: _NeverVerifier()
    client = TestClient(app)

    res = client.post(
        "/narration",
        json={
            "place_name": "x",
            "location": "y",
            "wikidata_id": "Q1",
            "language": "en",
        },
    )
    assert res.status_code == 401


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_succeeds_without_subscription(gen_narration):
    """付費牆已暫時移除（ADR 0006）：未訂閱者也能生成完整故事。"""
    gen_narration.return_value = NarrationResponse(
        place_name="P",
        location="L",
        era="modern",
        paragraphs=["a", "b", "c"],
        pull_quote="q",
        insufficient_source=False,
    )
    client = TestClient(_make_app())  # default: not subscribed

    res = client.post(
        "/narration",
        json={"wikidata_id": "Q1", "place_name": "P", "language": "en"},
    )

    assert res.status_code == 200
    gen_narration.assert_called_once()


@patch("lorescape_backend.narration.routes.service.generate_hooks")
def test_hooks_stay_free_for_unsubscribed_users(gen_hooks):
    """/narration/hooks 一直都免費，付費牆移除後行為不變。"""
    gen_hooks.return_value = HooksResponse(
        hooks=[HookItem(id="h1", title="T", teaser="t")],
        insufficient_source=False,
    )
    client = TestClient(_make_app())  # not subscribed

    res = client.post(
        "/narration/hooks",
        json={"wikidata_id": "Q1", "place_name": "P", "language": "en"},
    )

    assert res.status_code == 200


# ---------------------------------------------------------------------------
# Daily free quota gate
# ---------------------------------------------------------------------------

_NARRATION_BODY = {
    "place_name": "Arles",
    "location": "Provence",
    "wikipedia_title": "Arles",
    "language": "zh-TW",
    "hook": {"id": "h", "title": "梵谷", "teaser": "444 天"},
}


def _narration_result() -> NarrationResponse:
    return NarrationResponse(
        place_name="亞爾",
        location="法國普羅旺斯",
        era="十九世紀末",
        paragraphs=["一", "二", "三"],
        pull_quote="",
        insufficient_source=False,
    )


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_free_user_first_narration_of_the_day_succeeds_and_consumes(gen):
    gen.return_value = _narration_result()
    usage = _FakeUsage(used=0)
    client = TestClient(_make_app(usage=usage))

    response = client.post("/narration", json=_NARRATION_BODY)

    assert response.status_code == 200
    assert usage.consumed == 1


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_free_user_second_narration_of_the_day_is_paywalled(gen):
    gen.return_value = _narration_result()
    usage = _FakeUsage(used=1)
    client = TestClient(_make_app(usage=usage))

    response = client.post("/narration", json=_NARRATION_BODY)

    assert response.status_code == 402
    assert response.json()["detail"] == "Daily free quota exhausted"
    # The gate must run before generation — a paywalled call costs nothing.
    gen.assert_not_called()
    assert usage.consumed == 0


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_premium_user_is_never_gated_and_never_counted(gen):
    gen.return_value = _narration_result()
    usage = _FakeUsage(used=99)
    client = TestClient(
        _make_app(subscriptions=_FakeSubscriptions(premium=True), usage=usage)
    )

    response = client.post("/narration", json=_NARRATION_BODY)

    assert response.status_code == 200
    assert usage.consumed == 0


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_cache_hit_is_still_paywalled_for_an_exhausted_free_user(gen):
    # Warm the cache with a first call, then a second call by a user who
    # has already used today's quota must still be paywalled.
    gen.return_value = _narration_result()
    cache = _FakeNarrationCache()
    first = TestClient(_make_app(narration_cache=cache, usage=_FakeUsage(used=0)))
    assert first.post("/narration", json=_NARRATION_BODY).status_code == 200

    gen.reset_mock()
    exhausted = _FakeUsage(used=1)
    second = TestClient(
        _make_app(narration_cache=cache, usage=exhausted)
    )
    response = second.post("/narration", json=_NARRATION_BODY)

    assert response.status_code == 402
    gen.assert_not_called()
    assert exhausted.consumed == 0


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_cache_hit_consumes_quota_for_a_free_user_with_quota_left(gen):
    gen.return_value = _narration_result()
    cache = _FakeNarrationCache()
    first = TestClient(_make_app(narration_cache=cache, usage=_FakeUsage(used=0)))
    assert first.post("/narration", json=_NARRATION_BODY).status_code == 200

    gen.reset_mock()
    fresh = _FakeUsage(used=0)
    second = TestClient(_make_app(narration_cache=cache, usage=fresh))
    response = second.post("/narration", json=_NARRATION_BODY)

    assert response.status_code == 200
    # Served from cache — no generation — but the quota is still spent.
    gen.assert_not_called()
    assert fresh.consumed == 1


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_generation_failure_does_not_consume_quota(gen):
    """ADR 0009 明講生成失敗不消耗額度；目前只是 post_narration 敘述順序
    自然成立，沒有測試釘住——有人把 usage.consume() 往上搬會靜默破壞。"""
    gen.side_effect = UnsupportedLanguageError("unsupported")
    usage = _FakeUsage(used=0)
    client = TestClient(_make_app(usage=usage))

    response = client.post("/narration", json=_NARRATION_BODY)

    assert response.status_code != 200
    assert usage.consumed == 0


# ---------------------------------------------------------------------------
# Hooks cache behaviour
# ---------------------------------------------------------------------------

@patch("lorescape_backend.narration.routes.service.generate_hooks")
def test_hooks_cache_miss_generates_then_stores(gen_hooks):
    gen_hooks.return_value = HooksResponse(
        hooks=[HookItem(id="h1", title="T", teaser="t")],
        insufficient_source=False,
    )
    cache = _FakeHooksCache()
    client = TestClient(_make_app(hooks_cache=cache))

    res = client.post(
        "/narration/hooks",
        json={"wikidata_id": "Q48292", "place_name": "Arles", "language": "en"},
    )

    assert res.status_code == 200
    gen_hooks.assert_called_once()
    assert ("Q48292", "en") in cache.store


@patch("lorescape_backend.narration.routes.service.generate_hooks")
def test_hooks_cache_hit_skips_generation(gen_hooks):
    cache = _FakeHooksCache()
    cache.store[("Q48292", "en")] = HooksResponse(
        hooks=[HookItem(id="cached", title="Cached", teaser="c")],
        insufficient_source=False,
    )
    client = TestClient(_make_app(hooks_cache=cache))

    res = client.post(
        "/narration/hooks",
        json={"wikidata_id": "Q48292", "place_name": "Arles", "language": "en"},
    )

    assert res.status_code == 200
    assert res.json()["hooks"][0]["id"] == "cached"
    gen_hooks.assert_not_called()


@patch("lorescape_backend.narration.routes.service.generate_hooks")
def test_hooks_cache_is_language_scoped(gen_hooks):
    gen_hooks.return_value = HooksResponse(
        hooks=[HookItem(id="fresh", title="T", teaser="t")],
        insufficient_source=False,
    )
    cache = _FakeHooksCache()
    cache.store[("Q48292", "en")] = HooksResponse(
        hooks=[HookItem(id="cached-en", title="C", teaser="c")],
        insufficient_source=False,
    )
    client = TestClient(_make_app(hooks_cache=cache))

    res = client.post(
        "/narration/hooks",
        json={
            "wikidata_id": "Q48292", "place_name": "亞爾", "language": "zh-TW",
        },
    )

    assert res.json()["hooks"][0]["id"] == "fresh"  # en cache not reused
    gen_hooks.assert_called_once()


# ---------------------------------------------------------------------------
# Narration cache behaviour
# ---------------------------------------------------------------------------

def _story(paragraphs: list[str]) -> NarrationResponse:
    return NarrationResponse(
        place_name="亞爾",
        location="法國普羅旺斯",
        era="十九世紀末",
        paragraphs=paragraphs,
        pull_quote="",
        insufficient_source=False,
    )


def _narration_body(hook_id: str | None = "h1", language: str = "zh-TW") -> dict:
    body: dict = {
        "place_name": "Arles",
        "location": "Provence",
        "wikidata_id": "Q48292",
        "language": language,
    }
    if hook_id is not None:
        body["hook"] = {"id": hook_id, "title": "梵谷", "teaser": "444 天"}
    return body


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_cache_miss_generates_then_stores(gen_narration):
    gen_narration.return_value = _story(["一", "二", "三"])
    cache = _FakeNarrationCache()
    client = TestClient(_make_app(narration_cache=cache))

    response = client.post("/narration", json=_narration_body())

    assert response.status_code == 200
    assert gen_narration.call_count == 1
    assert cache.store[("Q48292", "zh-TW", "h1")].paragraphs == ["一", "二", "三"]


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_cache_hit_skips_generation(gen_narration):
    cache = _FakeNarrationCache()
    cache.store[("Q48292", "zh-TW", "h1")] = _story(["快取一", "快取二"])
    client = TestClient(_make_app(narration_cache=cache))

    response = client.post("/narration", json=_narration_body())

    assert response.status_code == 200
    assert response.json()["paragraphs"] == ["快取一", "快取二"]
    gen_narration.assert_not_called()


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_cache_is_scoped_per_hook(gen_narration):
    gen_narration.return_value = _story(["別的角度"])
    cache = _FakeNarrationCache()
    cache.store[("Q48292", "zh-TW", "h1")] = _story(["快取一"])
    client = TestClient(_make_app(narration_cache=cache))

    response = client.post("/narration", json=_narration_body(hook_id="h2"))

    assert response.status_code == 200
    assert response.json()["paragraphs"] == ["別的角度"]
    assert gen_narration.call_count == 1


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_without_hook_uses_empty_hook_id(gen_narration):
    gen_narration.return_value = _story(["無鉤子"])
    cache = _FakeNarrationCache()
    client = TestClient(_make_app(narration_cache=cache))

    response = client.post("/narration", json=_narration_body(hook_id=None))

    assert response.status_code == 200
    assert ("Q48292", "zh-TW", "") in cache.store


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_cache_is_language_scoped(gen_narration):
    gen_narration.return_value = _story(["English one"])
    cache = _FakeNarrationCache()
    cache.store[("Q48292", "zh-TW", "h1")] = _story(["中文一"])
    client = TestClient(_make_app(narration_cache=cache))

    response = client.post(
        "/narration", json=_narration_body(language="en")
    )

    assert response.status_code == 200
    assert response.json()["paragraphs"] == ["English one"]


@patch("lorescape_backend.narration.routes.service.generate_narration")
def test_narration_survives_a_broken_cache(gen_narration):
    """Supabase 整個掛掉（讀寫都炸）時，/narration 仍要正常回傳剛生成的
    故事——用真正的 NarrationCacheRepository（不是路由自己 try/except），
    證明吞例外的責任在 repository 這一層，路由本身不用知道快取死活。"""
    gen_narration.return_value = _story(["一", "二"])

    broken_client = MagicMock()
    broken_client.table.side_effect = RuntimeError("supabase down")
    cache = NarrationCacheRepository(broken_client)

    app = _make_app()
    app.dependency_overrides[get_narration_cache_repository] = lambda: cache
    client = TestClient(app)

    response = client.post("/narration", json=_narration_body())

    assert response.status_code == 200
    assert response.json()["paragraphs"] == ["一", "二"]
    gen_narration.assert_called_once()
