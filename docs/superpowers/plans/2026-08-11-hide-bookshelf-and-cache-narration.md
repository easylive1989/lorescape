# 隱藏書架 ＆ 故事導覽 DB 快取 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把書架（旅程／歷程）功能對使用者藏起來（程式碼保留），並讓
`/narration` 的生成結果存進 Supabase，同景點＋同語言＋同鉤子下次直接回放。

**Architecture:** 後端比照既有的 `narration_hooks_cache` 再開一張
`narration_cache` 表，由 `NarrationCacheRepository` 讀寫，`post_narration`
先查快取再決定要不要打 Gemini；快取任何失敗都吞掉並降級成正常生成。前端加一支
編譯期常數 `kBookshelfEnabled`，同時控制首頁入口按鈕與六條 `/journey`、
`/trip*` 路由的註冊。

**Tech Stack:** Python 3 / FastAPI / Pydantic / Supabase（後端）、
Flutter / Riverpod / go_router（前端）、pytest、flutter_test。

## Global Constraints

- 一律用 `fvm` 執行 flutter / dart 指令。
- 每次前端改動後跑 `fvm flutter analyze --fatal-infos`，零問題才算完成。
- 後端依賴用 uv：測試指令是 `uv run pytest`（在 `backend/` 目錄下）。
- 文件與註解以繁體中文撰寫（技術名詞除外）。
- 前端測試命名一律 BDD：`given X, when Y, then Z`；用 `test/helpers/pump_app.dart`
  的 `pumpScreen` / `pumpRouterApp`，不要 `mocktail`，改用 `test/fakes/` 下的 fake。
- 快取的失敗策略不可妥協：讀寫都必須吞例外並 log，絕不讓快取問題讓
  `/narration` 回錯誤。
- 新表的 `GRANT` 必須跟 `CREATE TABLE` 寫在同一份 migration
  （鉤子表就是因為分兩份寫漏了 grant，白白 regenerate 一個月）。
- 分支：`feat/hide-bookshelf-cache-narration`（已建立，spec 已 commit 在上面）。

## File Structure

**後端（新增／修改）**
- `backend/src/lorescape_backend/narration/cache.py` — 既有檔案，新增
  `hook_id_for()` 與 `NarrationCacheRepository`；`place_key_for()` 的型別放寬到
  同時吃 `HooksRequest | NarrationRequest`。
- `backend/src/lorescape_backend/narration/dependencies.py` — 新增
  `get_narration_cache_repository`。
- `backend/src/lorescape_backend/narration/routes.py` — `post_narration` 接上快取。
- `backend/tests/narration/test_cache.py` — 新增 repository 的單元測試。
- `backend/tests/narration/test_routes.py` — 新增 `_FakeNarrationCache` 與路由層測試。

**Supabase**
- `supabase/migrations/20260811000000_create_narration_cache.sql` — 建表＋RLS＋grant。

**前端（新增／修改）**
- `frontend/lib/app/config/feature_flags.dart` — 新檔，只放 `kBookshelfEnabled`。
- `frontend/lib/features/home/presentation/widgets/home_top_bar.dart` —
  `onOpenJourney` 改 nullable，為 null 時不 render 按鈕。
- `frontend/lib/features/home/presentation/screens/globe_home_screen.dart` —
  依 flag 決定傳 callback 還是 null。
- `frontend/lib/app/config/router_config.dart` — 六條路由包進 collection-if。
- `frontend/test/features/home/presentation/screens/globe_home_screen_test.dart` —
  既有的「點書架按鈕會開 journey」測試改成「按鈕不存在」。
- `frontend/test/app/config/router_config_test.dart` — 既有斷言含 `/journey`，要改。

**不動**：`features/journey/`、`features/trip/` 的實作與既有測試；前端不碰
narration 快取（純後端）。

---

### Task 1: 後端 narration 快取 repository

**Files:**
- Modify: `backend/src/lorescape_backend/narration/cache.py`
- Test: `backend/tests/narration/test_cache.py`

**Interfaces:**
- Consumes: 既有的 `place_key_for(request)`、`NarrationRequest`、`NarrationResponse`。
- Produces:
  - `hook_id_for(request: NarrationRequest) -> str`
  - `NarrationCacheRepository(client)`，方法
    `get(place_key: str, language: str, hook_id: str) -> NarrationResponse | None`
    與 `put(place_key: str, language: str, hook_id: str, result: NarrationResponse) -> None`
  - 模組常數 `_NARRATION_TABLE = "narration_cache"`

- [ ] **Step 1: 寫失敗的測試**

在 `backend/tests/narration/test_cache.py` 檔尾追加（檔案開頭的 import 也要補上
`NarrationCacheRepository`、`hook_id_for`、`NarrationRequest`、`NarrationResponse`）：

```python
def _narration_client_returning(rows: list[dict]) -> MagicMock:
    """Supabase client whose 3-eq select chain resolves to `rows`."""
    client = MagicMock()
    (
        client.table.return_value.select.return_value
        .eq.return_value.eq.return_value.eq.return_value
        .limit.return_value.execute.return_value
    ) = SimpleNamespace(data=rows)
    return client


def _narration(paragraphs: list[str]) -> NarrationResponse:
    return NarrationResponse(
        place_name="亞爾",
        location="法國普羅旺斯",
        era="十九世紀末",
        paragraphs=paragraphs,
        pull_quote="",
        insufficient_source=False,
    )


def test_hook_id_uses_the_chosen_hook():
    req = NarrationRequest(
        wikidata_id="Q48292",
        place_name="Arles",
        language="en",
        hook=HookItem(id="van-gogh-1888", title="T", teaser="t"),
    )
    assert hook_id_for(req) == "van-gogh-1888"


def test_hook_id_is_empty_string_without_a_hook():
    req = NarrationRequest(
        wikidata_id="Q48292", place_name="Arles", language="en",
    )
    assert hook_id_for(req) == ""


def test_narration_get_returns_parsed_response_on_hit():
    client = _narration_client_returning(
        [{"narration": _narration(["一", "二", "三"]).model_dump()}]
    )
    repo = NarrationCacheRepository(client)

    result = repo.get("Q48292", "zh-TW", "h1")

    assert result is not None
    assert result.paragraphs == ["一", "二", "三"]
    assert result.insufficient_source is False


def test_narration_get_returns_none_on_miss():
    repo = NarrationCacheRepository(_narration_client_returning([]))
    assert repo.get("Q1", "zh-TW", "h1") is None


def test_narration_get_returns_none_when_client_raises():
    client = MagicMock()
    client.table.side_effect = RuntimeError("supabase down")
    repo = NarrationCacheRepository(client)

    assert repo.get("Q1", "zh-TW", "h1") is None  # never raises


def test_narration_put_upserts_full_response():
    client = MagicMock()
    repo = NarrationCacheRepository(client)

    repo.put("Q48292", "zh-TW", "h1", _narration(["一", "二", "三"]))

    payload = client.table.return_value.upsert.call_args.args[0]
    assert payload["place_key"] == "Q48292"
    assert payload["language"] == "zh-TW"
    assert payload["hook_id"] == "h1"
    assert payload["narration"]["paragraphs"] == ["一", "二", "三"]


def test_narration_put_skips_insufficient_and_empty_results():
    client = MagicMock()
    repo = NarrationCacheRepository(client)

    repo.put("Q1", "zh-TW", "h1", _narration([]))
    insufficient = _narration(["一"])
    insufficient.insufficient_source = True
    repo.put("Q1", "zh-TW", "h1", insufficient)

    client.table.assert_not_called()


def test_narration_put_swallows_client_errors():
    client = MagicMock()
    client.table.side_effect = RuntimeError("supabase down")
    repo = NarrationCacheRepository(client)

    repo.put("Q1", "zh-TW", "h1", _narration(["一"]))  # must not raise
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
cd backend && uv run pytest tests/narration/test_cache.py -v
```

Expected: FAIL — `ImportError: cannot import name 'NarrationCacheRepository'`

- [ ] **Step 3: 實作**

在 `backend/src/lorescape_backend/narration/cache.py`：

3a. 檔案最上方的 docstring 補一段（現有 docstring 只講 hooks）：

```python
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
```

3b. import 補上兩個模型：

```python
from lorescape_backend.narration.models import (
    HookItem,
    HooksRequest,
    HooksResponse,
    NarrationRequest,
    NarrationResponse,
)
```

3c. 表名常數（放在既有的 `_TABLE` 下面）：

```python
_TABLE = "narration_hooks_cache"
_NARRATION_TABLE = "narration_cache"
```

3d. `place_key_for` 的簽章放寬——兩種 request 的識別欄位一模一樣，共用一支：

```python
def place_key_for(request: HooksRequest | NarrationRequest) -> str:
    """Stable cache key: Q-id, or a title-prefixed key on the legacy path."""
    if request.wikidata_id:
        return request.wikidata_id
    return f"title:{request.wikipedia_title}"


def hook_id_for(request: NarrationRequest) -> str:
    """Key part for the chosen angle; '' when generated without a hook."""
    return request.hook.id if request.hook else ""
```

3e. 檔尾新增 repository：

```python
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
```

- [ ] **Step 4: 跑測試確認通過**

```bash
cd backend && uv run pytest tests/narration/ -v
```

Expected: PASS（既有的 hooks 測試也要全綠——`place_key_for` 的簽章只是放寬）

- [ ] **Step 5: Commit**

```bash
git add backend/src/lorescape_backend/narration/cache.py backend/tests/narration/test_cache.py
git commit -m "feat(narration): 新增 NarrationCacheRepository"
```

---

### Task 2: 建表 migration ＋ 路由接上快取

**Files:**
- Create: `supabase/migrations/20260811000000_create_narration_cache.sql`
- Modify: `backend/src/lorescape_backend/narration/dependencies.py`
- Modify: `backend/src/lorescape_backend/narration/routes.py:63-81`
- Test: `backend/tests/narration/test_routes.py`

**Interfaces:**
- Consumes: Task 1 的 `NarrationCacheRepository`、`hook_id_for`、`place_key_for`。
- Produces: `get_narration_cache_repository(client) -> NarrationCacheRepository`
  （FastAPI dependency，測試用 `app.dependency_overrides` 覆寫）。

- [ ] **Step 1: 寫 migration**

建立 `supabase/migrations/20260811000000_create_narration_cache.sql`：

```sql
-- Cache for /narration results (the long-form story).
--
-- Every generation costs a grounded Gemini call. The first request for a
-- (place, language, hook) triple pays that cost; every later request is
-- served from this table, so the same place + same chosen angle always
-- replays the same story.
--
-- Written and read ONLY by the backend (service role). place_key is the
-- Wikidata Q-id for the modern request path, or "title:<wikipedia_title>"
-- for the deprecated title-only path. hook_id is the chosen hook's id, or
-- '' when the story was generated without one. Only successful
-- generations are cached (never insufficient_source / empty paragraphs),
-- so a place that failed once can succeed later.
CREATE TABLE IF NOT EXISTS public.narration_cache (
  place_key  TEXT NOT NULL,
  language   TEXT NOT NULL,
  hook_id    TEXT NOT NULL,
  narration  JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (place_key, language, hook_id)
);

-- Backend-only table: enable RLS with no policies so anon/authenticated
-- clients can do nothing; the service role bypasses RLS.
ALTER TABLE public.narration_cache ENABLE ROW LEVEL SECURITY;

-- Granted here, in the same migration as the CREATE — narration_hooks_cache
-- shipped without a grant and silently failed every read/write for a month
-- (see 20260705120001).
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.narration_cache TO service_role;
```

- [ ] **Step 2: 寫失敗的路由測試**

在 `backend/tests/narration/test_routes.py`：

2a. import 補上（檔案最上方，接在既有 import 之後）：

```python
from lorescape_backend.narration.dependencies import (
    get_hooks_cache_repository,
    get_narration_cache_repository,
)
```

2b. 在 `_FakeHooksCache` 底下新增：

```python
class _FakeNarrationCache:
    """In-memory stand-in for NarrationCacheRepository."""

    def __init__(self) -> None:
        self.store: dict[tuple[str, str, str], NarrationResponse] = {}
        self.put_calls: int = 0

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
        self.put_calls += 1
        if result.insufficient_source or not result.paragraphs:
            return
        self.store[(place_key, language, hook_id)] = result
```

2c. `_make_app` 加參數與 override：

```python
def _make_app(
    hooks_cache: _FakeHooksCache | None = None,
    narration_cache: _FakeNarrationCache | None = None,
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
    return app
```

2d. 檔尾追加測試：

```python
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
    """讀寫都炸掉時，端點仍要正常回傳生成結果。"""
    gen_narration.return_value = _story(["一", "二"])

    class _BrokenCache:
        def get(self, place_key, language, hook_id):
            raise RuntimeError("must be swallowed by the route's repository")

        def put(self, place_key, language, hook_id, result):
            raise RuntimeError("must be swallowed by the route's repository")

    app = _make_app()
    app.dependency_overrides[get_narration_cache_repository] = _BrokenCache
    client = TestClient(app)

    with pytest.raises(RuntimeError):
        client.post("/narration", json=_narration_body())
```

> 注意最後一個測試：真正的吞例外發生在 `NarrationCacheRepository` 內部（Task 1
> 已測過），路由層不再多包一層 try。這個測試就是把「路由不吞、由 repository 吞」
> 這個分工釘住——所以它斷言例外會往外冒。檔案最上方要 `import pytest`。

- [ ] **Step 3: 跑測試確認失敗**

```bash
cd backend && uv run pytest tests/narration/test_routes.py -v
```

Expected: FAIL — `ImportError: cannot import name 'get_narration_cache_repository'`

- [ ] **Step 4: 實作 dependency**

`backend/src/lorescape_backend/narration/dependencies.py` 整份改成：

```python
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
```

- [ ] **Step 5: 實作路由**

`backend/src/lorescape_backend/narration/routes.py`：

5a. import 改成：

```python
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
```

5b. `post_narration` 整支換成：

```python
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
```

- [ ] **Step 6: 跑全部後端測試**

```bash
cd backend && uv run pytest
```

Expected: PASS（全部，含 `test_api.py`）

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260811000000_create_narration_cache.sql \
        backend/src/lorescape_backend/narration/dependencies.py \
        backend/src/lorescape_backend/narration/routes.py \
        backend/tests/narration/test_routes.py
git commit -m "feat(narration): /narration 結果存 Supabase 快取"
```

> **部署提醒（不在本 plan 的自動化範圍）**：這張表要生效，得先
> `supabase db push` 套用 migration，再手動觸發 `deploy-backend.yml`。

---

### Task 3: 前端 feature flag ＋ 隱藏書架入口

**Files:**
- Create: `frontend/lib/app/config/feature_flags.dart`
- Modify: `frontend/lib/features/home/presentation/widgets/home_top_bar.dart:17-28,80-86`
- Modify: `frontend/lib/features/home/presentation/screens/globe_home_screen.dart:169`
- Test: `frontend/test/features/home/presentation/screens/globe_home_screen_test.dart:238-248`

**Interfaces:**
- Produces: `const bool kBookshelfEnabled`（`package:context_app/app/config/feature_flags.dart`），
  Task 4 也會用到；`HomeTopBar.onOpenJourney` 由 `VoidCallback` 變成 `VoidCallback?`。

- [ ] **Step 1: 改既有測試成失敗的測試**

`frontend/test/features/home/presentation/screens/globe_home_screen_test.dart`
把這段（約在 238–248 行）：

```dart
  testWidgets('given the globe home, '
      'when the user taps the shelf button, '
      'then the journey screen opens', (tester) async {
    final pushed = <Object?>[];
    await _givenHome(tester, pushed: pushed);

    await tester.tap(find.byKey(const Key('home-open-journey')));
    await tester.pumpAndSettle();

    expect(pushed, ['/journey']);
  });
```

整段換成：

```dart
  testWidgets('given the bookshelf feature is hidden, '
      'when the globe home renders its top bar, '
      'then no shelf button is offered', (tester) async {
    final pushed = <Object?>[];
    await _givenHome(tester, pushed: pushed);

    expect(find.byKey(const Key('home-open-journey')), findsNothing);
    expect(pushed, isEmpty);
  });
```

`_givenHome` 裡的 `/journey` stub route 保留不動——路由存在但沒人按得到，
正是這個測試要證明的事。

- [ ] **Step 2: 跑測試確認失敗**

```bash
cd frontend && fvm flutter test test/features/home/presentation/screens/globe_home_screen_test.dart
```

Expected: FAIL — `Expected: no matching candidates / Actual: found 1 widget`

- [ ] **Step 3: 建立 feature flag**

`frontend/lib/app/config/feature_flags.dart`：

```dart
/// 編譯期功能開關。只放「暫時關掉、日後可能整組打開」的旗標，
/// 不做通用的 remote config 機制。
library;

/// 書架（旅程／歷程）功能暫時隱藏（2026-08-11）。
///
/// 關掉時：首頁不顯示書架入口按鈕，且 `/journey`、`/trip*` 六條路由不註冊
/// ——殘留的 deep link 會落到 router 的 errorBuilder 導回首頁。
/// `features/journey/`、`features/trip/` 的程式碼與測試都保留，改回 `true`
/// 即整組復活，歷史記錄也還在（narration 播完仍照常寫入 journey）。
const bool kBookshelfEnabled = false;
```

- [ ] **Step 4: 入口按鈕改成可選**

4a. `home_top_bar.dart` 把欄位宣告改成 nullable（第 27 行）：

```dart
  /// 書架入口。傳 `null` 代表這顆按鈕整個不出現（見 [kBookshelfEnabled]）。
  final VoidCallback? onOpenJourney;
```

4b. 建構子的 `required this.onOpenJourney,`（第 17 行）改成
`this.onOpenJourney,`（nullable 不該是 required）。

4c. build 裡的按鈕（第 80–86 行）從：

```dart
              _RaisedIconButton(
                key: const Key('home-open-journey'),
                icon: Icons.menu_book_outlined,
                label: 'home.open_journey'.tr(),
                onPressed: onOpenJourney,
              ),
              const SizedBox(width: 8),
```

改成：

```dart
              if (onOpenJourney case final openJourney?) ...[
                _RaisedIconButton(
                  key: const Key('home-open-journey'),
                  icon: Icons.menu_book_outlined,
                  label: 'home.open_journey'.tr(),
                  onPressed: openJourney,
                ),
                const SizedBox(width: 8),
              ],
```

（連同後面那個 `SizedBox(width: 8)` 一起收進去——它是書架與設定兩顆按鈕之間的
間距，書架消失後它就沒有存在意義。）

- [ ] **Step 5: 首頁依 flag 傳 null**

`globe_home_screen.dart`：

5a. import 補上（依字母序放進既有的 `package:context_app/...` import 群）：

```dart
import 'package:context_app/app/config/feature_flags.dart';
```

5b. 第 169 行：

```dart
                    onOpenJourney: () => context.push('/journey'),
```

改成：

```dart
                    onOpenJourney: kBookshelfEnabled
                        ? () => context.push('/journey')
                        : null,
```

- [ ] **Step 6: 跑測試與 analyze**

```bash
cd frontend && fvm flutter test test/features/home/ && fvm flutter analyze --fatal-infos
```

Expected: 測試 PASS、analyze 零問題。

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/app/config/feature_flags.dart \
        frontend/lib/features/home/presentation/widgets/home_top_bar.dart \
        frontend/lib/features/home/presentation/screens/globe_home_screen.dart \
        frontend/test/features/home/presentation/screens/globe_home_screen_test.dart
git commit -m "feat(home): 以 kBookshelfEnabled 隱藏書架入口"
```

---

### Task 4: 停用書架相關路由

**Files:**
- Modify: `frontend/lib/app/config/router_config.dart:97-100,180-207`
- Test: `frontend/test/app/config/router_config_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `kBookshelfEnabled`。

- [ ] **Step 1: 改測試**

`frontend/test/app/config/router_config_test.dart` 整份換成：

```dart
import 'package:context_app/app/config/feature_flags.dart';
import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

List<String> _routePaths() {
  final container = ProviderContainer(
    overrides: [
      // Avoids touching Firebase during router construction (see
      // router_splash_test.dart for the same workaround).
      routeObserversProvider.overrideWithValue(const []),
    ],
  );
  addTearDown(container.dispose);

  return container
      .read(routerProvider)
      .configuration
      .routes
      .whereType<GoRoute>()
      .map((route) => route.path)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('given the app router, '
      'when listing its top-level routes, '
      'then the flat globe-home layout is in place', () {
    expect(_routePaths(), containsAll(['/', '/map', '/settings']));
  });

  test('given the bookshelf feature is hidden, '
      'when listing the router top-level routes, '
      'then no journey or trip route is registered', () {
    expect(kBookshelfEnabled, isFalse);

    expect(
      _routePaths(),
      isNot(
        anyElement(
          anyOf(equals('/journey'), startsWith('/trip')),
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
cd frontend && fvm flutter test test/app/config/router_config_test.dart
```

Expected: FAIL — 第二個測試找到 `/journey`（第一個測試會通過，它只是拿掉了
`/journey` 這一項）

- [ ] **Step 3: 路由包進 flag**

`router_config.dart`：

3a. import 補上（依字母序放在既有 import 最前面那群）：

```dart
import 'package:context_app/app/config/feature_flags.dart';
```

3b. `/journey` 那條（第 96–100 行）：

```dart
        GoRoute(
          path: '/journey',
          name: 'journey',
          builder: (context, state) => const JourneyScreen(),
        ),
```

改成：

```dart
        // 書架整組暫時隱藏；未註冊的 path 會落到下方的 errorBuilder
        // → RedirectToHome，殘留的 deep link 自動回首頁。
        if (kBookshelfEnabled)
          GoRoute(
            path: '/journey',
            name: 'journey',
            builder: (context, state) => const JourneyScreen(),
          ),
```

3c. 檔案下方 `/trips` 到 `/trip/:id` 那五條（第 179–207 行，
`GoRoute(path: '/trips', ...)` 起到 `trip_detail` 那條的 `),` 為止）
整段包進一個 collection-if：

```dart
        if (kBookshelfEnabled) ...[
          GoRoute(
            path: '/trips',
            name: 'trips',
            builder: (context, state) => const TripListScreen(),
          ),
          GoRoute(
            path: '/trip/edit',
            name: 'trip_create',
            builder: (context, state) => const TripEditScreen(),
          ),
          GoRoute(
            path: '/trip/edit/:id',
            name: 'trip_edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TripEditScreen(tripId: id);
            },
          ),
          GoRoute(
            path: '/trip/uncategorized',
            name: 'trip_uncategorized',
            builder: (context, state) => const TripDetailScreen(),
          ),
          GoRoute(
            path: '/trip/:id',
            name: 'trip_detail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return TripDetailScreen(tripId: id);
            },
          ),
        ],
```

`JourneyScreen`、`TripListScreen`、`TripEditScreen`、`TripDetailScreen` 四個
import 都要保留——程式碼還在，只是條件式註冊。

- [ ] **Step 4: 跑測試確認通過**

```bash
cd frontend && fvm flutter test test/app/config/router_config_test.dart
```

Expected: PASS（兩個測試都綠）

- [ ] **Step 5: 跑全部前端測試與 analyze**

```bash
cd frontend && fvm flutter test && fvm flutter analyze --fatal-infos
```

Expected: 全綠、零問題。`journey_screen_test.dart`、`trip_bookshelf_test.dart`、
`trip_lifecycle_flow_test.dart` 等都應照常通過——它們用 `pumpScreen` /
`pumpRouterApp` 自建路由，不依賴 app router 的註冊。

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/app/config/router_config.dart \
        frontend/test/app/config/router_config_test.dart
git commit -m "feat(router): 書架隱藏時不註冊 journey/trip 路由"
```

---

## 完工驗收

全部 task 做完後跑一次：

```bash
cd frontend && fvm flutter analyze --fatal-infos && fvm flutter test
cd ../backend && uv run pytest
```

手動確認（需要真機／模擬器與已部署的後端，屬部署後的驗證，不阻擋 merge）：

- App 首頁右上角只剩設定按鈕，沒有書架按鈕。
- 手動導向 `/journey` 會回到首頁，不出現錯誤頁。
- 同景點、同語言、同鉤子連續生成兩次故事，第二次的後端 log 出現
  `narration.cache.hit`，且內容與第一次完全相同。
