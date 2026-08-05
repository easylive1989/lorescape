# 暫時移除付費牆設計（2026-08-05）

## 背景與目標

Lorescape 目前為 freemium + 訂閱制，唯一的實際擋點是 backend narration API 的
402 訂閱驗證：未訂閱者無法生成完整故事，會被導向 paywall。現在決定**暫時全面
免費**，讓所有使用者直接使用完整功能，不收錢。

決策脈絡：

- 之後功能會全面調整，付費方式也不一定繼續走訂閱制，因此**不做**一鍵恢復的
  feature flag，直接移除擋點即可。
- 採「最小移除」：只拿掉使用者會碰到的擋點與入口，subscription / usage 相關
  程式碼原地保留（不再被引用），留給未來全面調整時一併處理。
- 目前**沒有現有訂閱者**，App Store / Play 商店端的訂閱商品暫不下架——App 內
  已無購買入口，不會有人買到。
- 必須留下紀錄（ADR + backlog task），讓未來調整付費模式時記得先處理這個
  「死碼保留中」的狀態。

## 現況盤點（改動前）

免費使用者被擋的路徑：

1. 選景點 → `POST /narration/hooks`（免費、無檢查）→ 選故事角度
2. `POST /narration` → backend `narration/routes.py` 檢查
   `subscriptions.is_subscribed()` → 未訂閱回 **HTTP 402**
3. 前端把 402 映射為 `quotaExceeded`，`SelectStoryHookScreen` 監聽到後導向
   `/subscription` paywall
4. 另一入口：設定頁 `_UpgradeBanner` 主動導向 paywall

已確認**沒有其他 gating**：前端 `usage` feature（每日次數限制）是死碼，
`isPremiumProvider` 只影響設定頁 banner 文案與 usage repo 選擇；backend 沒有
daily quota 程式碼。

## 改動內容

### Backend（`backend/`）

- `src/lorescape_backend/narration/routes.py`：刪除 402 訂閱檢查段落，及該
  route 不再需要的 subscriptions 依賴注入參數。
- `tests/narration/test_routes.py`：刪除 `test_narration_returns_402_for_free_user`。
- **不動**：`subscriptions/` 模組（webhook、reconcile、service、repository）、
  排程 reconcile job、Supabase `subscriptions` / `daily_usage` 表與 RPC。
  webhook 沒人觸發、reconcile 每日空跑皆無害。

### Frontend（`frontend/`）

- `lib/features/settings/presentation/screens/settings_screen.dart`：移除
  `_UpgradeBanner`（含 premium 到期日顯示，已無意義）。
- `lib/features/narration/presentation/screens/select_story_hook_screen.dart`：
  移除 quotaExceeded → paywall 的導向監聽與 `_navigateToPaywall()`；402 不會再
  發生，quotaExceeded 若出現走一般錯誤處理。
- `lib/app/config/router_config.dart`：移除 `/subscription` 路由。
- **不動**：`features/subscription/`、`features/usage/` 整包、`main.dart` /
  `app.dart` 的 RevenueCat SDK 初始化與 logIn、`purchases_flutter` 依賴、
  翻譯檔 `subscription.*` key。
- 因移除引用而產生的 unused import / 警告修到 `fvm flutter analyze
  --fatal-infos` 全乾淨。

### Landing（`landing/`）

- `src/app/[locale]/page.tsx`：移除 Pricing 區塊掛載。
- **不動**：`src/components/Pricing.tsx`、`dictionaries.ts` 的 pricing 文案、
  legal 頁的訂閱條款文字。

### 紀錄

- 新增 `docs/adr/0006-temporarily-remove-paywall.md`：記錄決策、動過的檔案、
  刻意保留的死碼清單（subscription / usage feature、backend subscriptions
  模組、RC 整合、landing Pricing、商店端商品仍上架）、未來調整付費模式時的
  盤點清單。
- `BACKLOG.md` 新增一條 task 指向該 ADR。

## 不做的事（YAGNI）

- 不做 feature flag / 環境變數開關（已確認不需要一鍵恢復）。
- 不刪 subscription / usage 死碼、不移除 RevenueCat 依賴。
- 不下架商店端訂閱商品、不動 RevenueCat dashboard。
- 不改 App 商店描述與 `MARKETING.md`（行銷文案調整另案處理）。

## 測試策略

- Backend：`uv run pytest` 全綠（刪除 402 測試後，其餘 narration 測試涵蓋
  「未訂閱者可成功生成」的新行為——原本的成功案例測試即是）。
- Frontend：`fvm flutter analyze --fatal-infos` 零問題；`fvm flutter test`
  全綠（受影響的 settings / select_story_hook widget test 隨行為更新）。
- 不新增測試：本次是移除行為。

## 驗收標準

1. 未訂閱（含匿名）使用者可完整生成故事，不會遇到 402 或 paywall。
2. App 內不存在任何訂閱購買入口（設定頁無升級 banner、無 `/subscription`
   路由）。
3. 官網不顯示定價區塊。
4. ADR 0006 與 BACKLOG task 已建立。
5. 前後端測試與 analyze 全綠。
