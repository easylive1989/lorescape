# 暫時移除付費牆 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除 Lorescape 唯一的付費牆（backend 402 訂閱檢查）與 App 內所有訂閱入口，讓所有使用者免費使用完整功能，並以 ADR + BACKLOG 記錄「死碼保留中」的狀態。

**Architecture:** 最小移除——只動使用者會碰到的擋點與入口。backend 拿掉 `POST /narration` 的 402 檢查；frontend 移除設定頁升級 banner、quotaExceeded → paywall 導向、`/subscription` 路由；landing 移除 Pricing 掛載。subscription / usage feature、RevenueCat 整合、Supabase 表全部原地保留不動。

**Tech Stack:** FastAPI + pytest（uv）、Flutter + Riverpod + go_router（fvm）、Next.js。

**Spec:** `docs/superpowers/specs/2026-08-05-remove-paywall-design.md`

## Global Constraints

- Flutter / Dart 指令一律經 `fvm`（在 `frontend/` 下執行）。
- Backend 指令經 `uv`（在 `backend/` 下執行）。
- Frontend 完成後 `fvm flutter analyze --fatal-infos` 必須零問題。
- 文件（ADR、BACKLOG）以繁體中文撰寫，技術名詞除外。
- **不動**：`frontend/lib/features/subscription/`、`frontend/lib/features/usage/`、`main.dart` / `app.dart` 的 RevenueCat 初始化、`purchases_flutter` 依賴、翻譯檔 `subscription.*` key、`backend/src/lorescape_backend/subscriptions/`、Supabase migrations、`landing/src/components/Pricing.tsx`、`dictionaries.ts` pricing 文案。

---

### Task 1: Backend — 移除 /narration 的 402 訂閱檢查

**Files:**
- Modify: `backend/src/lorescape_backend/narration/routes.py`
- Test: `backend/tests/narration/test_routes.py`

**Interfaces:**
- Consumes: 無（第一個 task）。
- Produces: `POST /narration` 對任何已登入使用者回 200（不再有 402）。後續 frontend task 依賴此行為假設。

- [ ] **Step 1: 改寫 402 測試為「未訂閱者可生成」的失敗測試**

在 `backend/tests/narration/test_routes.py` 把整個 `test_narration_returns_402_for_free_user`（約 L256-268）替換為：

```python
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
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd backend && uv run pytest tests/narration/test_routes.py::test_narration_succeeds_without_subscription -v`
Expected: FAIL — `assert 402 == 200`

- [ ] **Step 3: 移除 routes.py 的 402 檢查**

`backend/src/lorescape_backend/narration/routes.py`：

1. 刪除 import（L25-28）：

```python
from lorescape_backend.subscriptions.dependencies import (
    get_subscription_checker,
)
from lorescape_backend.subscriptions.service import SubscriptionChecker
```

2. 第 6 行 fastapi import 移除 `status`（只有 402 那段在用）：

```python
from fastapi import APIRouter, Depends, HTTPException
```

3. `post_narration` 改為（移除 `subscriptions` 參數、402 區塊，docstring 更新）：

```python
@router.post("", response_model=NarrationResponse)
def post_narration(
    request: NarrationRequest,
    config: Config = Depends(get_config),
    user: AuthedUser = Depends(require_user),
) -> NarrationResponse:
    """Return the long-form 3-paragraph story for the given place.

    Free for every signed-in user: the subscription gate was
    temporarily removed (ADR 0006).
    """
    try:
        return service.generate_narration(
            settings=config.genai_settings,
            request=request,
            web_search=config.narration_web_search_enabled,
        )
    except service.UnsupportedLanguageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd backend && uv run pytest tests/narration/test_routes.py::test_narration_succeeds_without_subscription -v`
Expected: PASS

- [ ] **Step 5: 清掉測試檔中已無作用的訂閱 fake**

`backend/tests/narration/test_routes.py`：

1. 刪除 import（L17-19）：

```python
from lorescape_backend.subscriptions.dependencies import (
    get_subscription_checker,
)
```

2. 刪除整個 `_FakeSubscriptions` class（L32-39）。
3. `_make_app` 移除 `subscriptions` 參數與該 override（L60、L69-71）：

```python
def _make_app(
    hooks_cache: _FakeHooksCache | None = None,
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
    return app
```

4. 刪除 `_subscriber_app` helper（L78-80），其呼叫處（`test_post_narration_returns_payload`、`test_post_narration_rejects_unsupported_language`、`test_narration_route_accepts_wikidata_id`、`test_narration_route_accepts_legacy_wikipedia_title`）全改成 `TestClient(_make_app())`。
5. `test_narration_route_401_without_bearer_token` 刪除這行（L241）：

```python
    app.dependency_overrides[get_subscription_checker] = _FakeSubscriptions
```

6. 刪除整個 `test_premium_user_can_generate`（與 Step 1 的新測試重複——訂閱與否已無差別）。
7. `test_hooks_stay_free_for_unsubscribed_users` docstring 改為 `"""/narration/hooks 一直都免費，付費牆移除後行為不變。"""`（upsell funnel 已不存在）。

- [ ] **Step 6: 跑 backend 全部測試**

Run: `cd backend && uv run pytest`
Expected: 全綠（subscriptions 模組測試照常通過——模組本身沒動）。

- [ ] **Step 7: Commit**

```bash
git add backend/src/lorescape_backend/narration/routes.py backend/tests/narration/test_routes.py
git commit -m "feat(backend): 暫時移除 /narration 402 訂閱檢查（ADR 0006）"
```

---

### Task 2: Frontend — quotaExceeded 不再導向 paywall

**Files:**
- Modify: `frontend/lib/features/narration/presentation/screens/select_story_hook_screen.dart`
- Test: `frontend/test/features/narration/presentation/screens/select_story_hook_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 後 backend 不再回 402；`NarrationGenerationErrorType.quotaExceeded` 理論上不會再出現，但若出現改走一般錯誤 dialog。
- Produces: 畫面不再引用 route name `'subscription'`（Task 4 移除路由的前提）。

- [ ] **Step 1: 改寫 paywall 導向測試為「顯示一般錯誤 dialog」**

在 `frontend/test/features/narration/presentation/screens/select_story_hook_screen_test.dart` 把 `'given the backend reports quota exhausted (402), when a hook is tapped, then the subscription screen is shown'` 整個 testWidgets（約 L344-378）替換為：

```dart
    testWidgets(
      'given the backend reports quota exhausted, when a hook is tapped, '
      'then the generic error dialog is shown',
      (tester) async {
        await pumpRouterApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => SelectStoryHookScreen(place: buildPlace()),
            ),
          ],
          overrides: _overrides(
            hookService: _FakeStoryHookService(hooks: const [_hook1]),
            narrationService: FakeNarrationService(
              error: const AppError(type: NarrationError.freeQuotaExceeded),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_hook1.title));
        await tester.pumpAndSettle();

        expect(
          find.text('config_screen.generation_error_title'),
          findsOneWidget,
        );
      },
    );
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/narration/presentation/screens/select_story_hook_screen_test.dart`
Expected: 該測試 FAIL——現行程式會嘗試導向已不在測試路由表中的 `'subscription'`（丟路由錯誤或找不到 dialog 文字），其餘測試 PASS。

- [ ] **Step 3: 移除 paywall 導向**

`frontend/lib/features/narration/presentation/screens/select_story_hook_screen.dart`：

1. 刪除整個 `_navigateToPaywall` 方法（L97-100）。
2. `build` 內的 listener（L146-160）改為：

```dart
    ref.listen<NarrationGenerationState>(
      narrationGenerationControllerProvider,
      (previous, current) {
        if (previous?.isSuccess != true && current.isSuccess) {
          _navigateToPlayer(current);
        }
        if (previous?.hasError != true && current.hasError) {
          _showErrorDialog(current);
        }
      },
    );
```

3. `_onHookSelected` 內過時的註解（L57-59）改為：

```dart
    // The backend is the source of truth for generation errors; failures
    // surface via the generation-state listener below.
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/narration/presentation/screens/select_story_hook_screen_test.dart`
Expected: 全 PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/narration/presentation/screens/select_story_hook_screen.dart frontend/test/features/narration/presentation/screens/select_story_hook_screen_test.dart
git commit -m "feat(app): quotaExceeded 改走一般錯誤處理，不再導向 paywall（ADR 0006）"
```

---

### Task 3: Frontend — 移除設定頁升級 banner

**Files:**
- Modify: `frontend/lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `frontend/test/features/settings/presentation/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces: `SettingsScreen` 不再引用 `features/subscription/providers.dart` 與 route name `'subscription'`（Task 4 的前提）。

- [ ] **Step 1: 改寫設定頁測試——不再有升級 banner**

`frontend/test/features/settings/presentation/screens/settings_screen_test.dart`：

1. 把前兩個 testWidgets（free user 見 upgrade CTA、premium user 見 premium tile，約 L32-53）替換為單一測試：

```dart
    testWidgets('given the screen loads, '
        'then preferences are visible and there is no upgrade banner or '
        'daily-usage section', (tester) async {
      await _givenSettingsScreen(tester);

      _thenPreferencesSectionIsVisible();
      _thenUsageSectionIsHidden();
      // 付費牆已暫時移除（ADR 0006）：設定頁不再有任何訂閱入口。
      expect(find.text('subscription.upgrade_banner_title'), findsNothing);
      expect(find.text('subscription.premium_banner_title'), findsNothing);
    });
```

2. 刪除 import（L6-8）：

```dart
import 'package:context_app/features/subscription/domain/models/subscription_status.dart';
import 'package:context_app/features/subscription/providers.dart';
import 'package:context_app/features/usage/providers.dart';
```

與 L17 的 `import '../../../../fakes/in_memory_usage_repository.dart';`。

3. `_settingsOverrides` 移除 `usage`、`status` 參數與對應 overrides，改為：

```dart
List<Override> _settingsOverrides({FakeAuthService? authService}) {
  final auth = authService ?? FakeAuthService();

  return [
    authServiceProvider.overrideWithValue(auth),
    appVersionStringProvider.overrideWith((ref) async => _fakeVersionLabel),
    onboardingRepositoryProvider.overrideWithValue(
      InMemoryOnboardingRepository(welcomeDone: true),
    ),
  ];
}
```

4. `_givenSettingsScreen` 同步移除 `usage`、`status` 參數：

```dart
Future<void> _givenSettingsScreen(
  WidgetTester tester, {
  FakeAuthService? authService,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await pumpScreen(
    tester,
    child: const SettingsScreen(),
    overrides: _settingsOverrides(authService: authService),
  );
  await tester.pump(const Duration(milliseconds: 20));
}
```

（檔案原有的說明註解保留。）

5. 刪除 helpers `_thenUpgradeCtaIsVisible`、`_thenPremiumTileIsVisible`、`_thenUpgradeCtaIsHidden`（L250-260）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/settings/presentation/screens/settings_screen_test.dart`
Expected: 新的第一個測試 FAIL——畫面上仍有 `subscription.upgrade_banner_title`。若因移除 `subscriptionStatusProvider` override 而先炸出 provider 錯誤，同樣視為預期失敗。

- [ ] **Step 3: 移除 _UpgradeBanner**

`frontend/lib/features/settings/presentation/screens/settings_screen.dart`：

1. ListView children 移除這兩行（L37-38）：

```dart
                const _UpgradeBanner(),
                const SizedBox(height: 26),
```

2. 刪除整段 `_UpgradeBanner` class 與其上方的分隔註解（L60-152）。
3. 刪除 import（L6）：

```dart
import 'package:context_app/features/subscription/providers.dart';
```

4. 若 `go_router` import（L13）因此不再被使用（`context.pushNamed` 已移除，但 `_OnboardingGroup` 的 `context.go` 仍在用），保留；以 analyzer 結果為準。

- [ ] **Step 4: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/settings/presentation/screens/settings_screen_test.dart`
Expected: 全 PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/settings/presentation/screens/settings_screen.dart frontend/test/features/settings/presentation/screens/settings_screen_test.dart
git commit -m "feat(app): 移除設定頁訂閱升級 banner（ADR 0006）"
```

---

### Task 4: Frontend — 移除 /subscription 路由 + 全套驗證

**Files:**
- Modify: `frontend/lib/app/config/router_config.dart`

**Interfaces:**
- Consumes: Task 2、3 已移除所有 `pushNamed('subscription')` 呼叫。
- Produces: App 內已無任何訂閱入口（驗收標準 2）。

- [ ] **Step 1: 確認已無人引用 subscription 路由**

Run: `cd frontend && grep -rn "pushNamed('subscription')\|pushNamed(\"subscription\")" lib/`
Expected: 無輸出。若有輸出，表示 Task 2/3 沒清乾淨，先回頭處理。

- [ ] **Step 2: 移除路由**

`frontend/lib/app/config/router_config.dart`：

1. 刪除 GoRoute 區塊（L180-184）：

```dart
        GoRoute(
          path: '/subscription',
          name: 'subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
```

2. 刪除 import（L18）：

```dart
import 'package:context_app/features/subscription/presentation/screens/subscription_screen.dart';
```

- [ ] **Step 3: analyze 全乾淨**

Run: `cd frontend && fvm flutter analyze --fatal-infos`
Expected: `No issues found!`。有任何 unused import / warning 就修掉（僅限本次改動引起的）。

- [ ] **Step 4: 跑 frontend 全套測試**

Run: `cd frontend && fvm flutter test`
Expected: 全 PASS（`test/features/subscription/` 的既有測試測的是 feature 內部，未被本次改動影響；architecture dependency 測試亦應通過——settings 已不再跨 feature 引用 subscription）。

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/app/config/router_config.dart
git commit -m "feat(app): 移除 /subscription 路由（ADR 0006）"
```

---

### Task 5: Landing — 移除 Pricing 區塊掛載

**Files:**
- Modify: `landing/src/app/[locale]/page.tsx`

**Interfaces:**
- Consumes: 無。
- Produces: 官網不再顯示定價區塊（驗收標準 3）。`Pricing.tsx` 元件與字典文案保留。

- [ ] **Step 1: 移除掛載**

`landing/src/app/[locale]/page.tsx`：

1. 刪除 import（L10）：

```tsx
import Pricing from "@/components/Pricing";
```

2. 刪除 JSX（L32）：

```tsx
        <Pricing d={d.pricing} />
```

- [ ] **Step 2: 建置驗證**

Run: `cd landing && npm run build`
Expected: build 成功、無 type error（`Pricing.tsx` 未被引用但仍可編譯）。

- [ ] **Step 3: Commit**

```bash
git add "landing/src/app/[locale]/page.tsx"
git commit -m "feat(landing): 移除定價區塊掛載（ADR 0006）"
```

---

### Task 6: 紀錄 — ADR 0006 + BACKLOG

**Files:**
- Create: `docs/adr/0006-temporarily-remove-paywall.md`
- Modify: `BACKLOG.md`

**Interfaces:**
- Consumes: Task 1-5 全部完成（ADR 記錄的是既成事實）。
- Produces: 未來調整付費模式時的盤點依據（驗收標準 4）。

- [ ] **Step 1: 撰寫 ADR 0006**

建立 `docs/adr/0006-temporarily-remove-paywall.md`，內容：

```markdown
# 0006. 暫時移除付費牆，App 全面免費

日期：2026-08-05
狀態：已採納

## 背景

Lorescape 原為 freemium + 訂閱制（RevenueCat）：`POST /narration` 對未訂閱
者回 402，App 收到後導向 paywall——這是全產品唯一的實際擋點。現決定暫時全
面免費開放。未來功能會全面調整，付費模式不一定續走訂閱制，因此不做可一鍵
恢復的 feature flag，直接移除擋點、其餘程式碼原地保留。決策當下沒有任何現
有訂閱者。

## 決策

- backend `narration/routes.py`：移除 `POST /narration` 的 402 訂閱檢查與
  該 route 對 subscriptions 模組的依賴。
- frontend：移除設定頁升級 banner、quotaExceeded → paywall 導向、
  `/subscription` 路由。
- landing：移除 Pricing 區塊掛載。

## 刻意保留的死碼（未來調整付費模式時的盤點起點）

- frontend `lib/features/subscription/` 整包（paywall UI、RevenueCat
  service、providers）與 `lib/features/usage/` 整包：仍在編譯，無人引用。
- frontend `main.dart` / `app.dart` 的 RevenueCat SDK 初始化與 logIn 仍每次
  啟動照常執行；`purchases_flutter` 依賴與翻譯檔 `subscription.*` key 保留。
- backend `subscriptions/` 模組照常運作（RevenueCat webhook、每日 03:00
  reconcile job），只是查詢結果不再被任何 route 使用。
- Supabase `subscriptions` / `daily_usage` 表與 RPC 原封不動。
- landing `src/components/Pricing.tsx` 與 `dictionaries.ts` 的 pricing 文案
  保留，只拿掉掛載。
- App Store / Play 商店端訂閱商品仍上架、RevenueCat offering 未動——App 內
  已無購買入口，實際上買不到。

## 影響與注意事項

- 重新收費時不必然恢復上述清單：付費模式可能整個改變，屆時以本清單為盤點
  起點，決定各項是恢復、改寫還是刪除。
- 商店描述與 `MARKETING.md` 仍描述訂閱制，行銷文案調整另案處理。
- 相關 spec：`docs/superpowers/specs/2026-08-05-remove-paywall-design.md`。
```

- [ ] **Step 2: BACKLOG.md 新增 F31 並更新待部署清單**

1. 在 `BACKLOG.md` 檔尾新增：

```markdown
## F31: 暫時移除付費牆（App 全面免費）

2026-08-05 決策：暫時全面免費，訂閱不再擋任何功能。詳見
`docs/adr/0006-temporarily-remove-paywall.md`——含刻意保留的死碼清單
（subscription / usage feature、RevenueCat 整合、Supabase 表、商店端商品），
**之後調整付費模式時要先讀該 ADR 盤點現狀**。

- [x] T1: backend 移除 /narration 402 訂閱檢查（2026-08-05）
- [x] T2: App 移除升級 banner、paywall 導向與 /subscription 路由（2026-08-05）
- [x] T3: 落地頁移除定價區塊（2026-08-05）
- [ ] T4: 部署後才對使用者生效——backend（Deploy Backend workflow）、落地頁
  （Deploy Landing workflow）、App 需出新版送審（見「待部署」段）
```

2. 在「## ⚠️ 待部署」段落內：
   - 新增兩行（放在現有 Backend / 落地頁項目附近）：

```markdown
- [ ] **Backend**（`backend/`）：F31 T1 付費牆移除（2026-08-05），需手動觸發 Deploy Backend workflow 才生效
- [ ] **落地頁**（`landing/`）：F31 T3 移除定價區塊（2026-08-05），需 Deploy Landing workflow 才生效
```

   - 在「**App**（`frontend/`，下一輪）：待下次 build 送審才生效的累積改動——」的子項清單末尾加一行（縮排比照既有子項）：

```markdown
  - F31 T2：移除升級 banner、paywall 導向與 /subscription 路由（2026-08-05）
```

- [ ] **Step 3: Commit**

```bash
git add docs/adr/0006-temporarily-remove-paywall.md BACKLOG.md
git commit -m "docs: ADR 0006 暫時移除付費牆 + BACKLOG F31"
```

注意：`BACKLOG.md` 在工作目錄可能已有其他未提交修改——只 stage 本次相關的 hunk（`git add -p BACKLOG.md`），或先確認既有修改內容再一併處理。

---

## 完成後驗收（對照 spec）

1. 未訂閱使用者可完整生成故事（Task 1 測試涵蓋）。
2. App 內無任何訂閱購買入口（Task 2-4）。
3. 官網無定價區塊（Task 5）。
4. ADR 0006 與 BACKLOG F31 已建立（Task 6）。
5. `uv run pytest`、`fvm flutter analyze --fatal-infos`、`fvm flutter test` 全綠（Task 1、4）。
6. 提醒使用者：部署（backend / landing workflow、App 送審）由使用者自行觸發，程式合併後尚未對使用者生效。
