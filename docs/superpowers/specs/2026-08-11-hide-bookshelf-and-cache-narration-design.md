# 隱藏書架 ＆ 故事導覽存 DB 快取

日期：2026-08-11

## 背景

兩件互相獨立的改動，一起處理：

1. **書架（旅程／歷程）暫時隱藏。** 目前首頁右上角有一顆 `menu_book_outlined`
   按鈕通往 `/journey`，該頁是旅程書架，每本書再進 `/trip/:id`。這整組功能要
   對使用者不可達，但程式碼保留、日後可復原。
2. **故事導覽（narration）要存 DB。** 同一景點、同一語言、同一個故事鉤子，
   下次應該拿到一模一樣的故事，不再重打 Gemini。

### 現況調查

- 書架子樹**完全自給自足**：所有 `/trip/*` 的 `context.push` 都發生在
  `features/journey/` 與 `features/trip/` 自己的畫面內，唯一的外部入口是
  `globe_home_screen.dart:169` 的 `onOpenJourney`。移掉入口即整棵子樹不可達，
  不會產生斷頭連結。`MidnightBottomNav` 目前沒有任何使用者。
- **故事鉤子的快取已經做好了**：`narration_hooks_cache` 表（migration
  `20260611000000`，權限補在 `20260705120001`），`narration/cache.py` 的
  `HooksCacheRepository` 以 `(place_key, language)` 為 key 讀寫，
  `routes.py` 的 `post_hooks` 已接上。**本次不動鉤子。**
- **故事導覽沒有任何快取**：`post_narration` 每次都直接呼叫
  `service.generate_narration`。

## 設計 A：隱藏書架

### Feature flag

新增 `frontend/lib/app/config/feature_flags.dart`，只放一個常數：

```dart
/// 書架（旅程／歷程）功能暫時隱藏（2026-08-11）。
/// 程式碼與測試保留，改回 true 即整組復活。
const bool kBookshelfEnabled = false;
```

專案目前沒有 feature flag 慣例，這是第一支；刻意只放這一個常數，不做通用機制。

### 兩個掛載點

1. **入口**（`globe_home_screen.dart` / `home_top_bar.dart`）：
   `HomeTopBar.onOpenJourney` 由 `VoidCallback` 改為 `VoidCallback?`；
   `globe_home_screen.dart` 在 `kBookshelfEnabled` 為 false 時傳 `null`；
   `home_top_bar.dart` 的 `_RaisedIconButton(key: Key('home-open-journey'))`
   在 callback 為 null 時不 render（連同它後面的 `SizedBox(width: 8)`）。

2. **路由**（`router_config.dart`）：以下六條包進
   `if (kBookshelfEnabled) ...[ ... ]`（`routes` 是 `List<RouteBase>`，
   可用 collection-if 展開）：

   | path | name |
   |---|---|
   | `/journey` | `journey` |
   | `/trips` | `trips` |
   | `/trip/edit` | `trip_create` |
   | `/trip/edit/:id` | `trip_edit` |
   | `/trip/uncategorized` | `trip_uncategorized` |
   | `/trip/:id` | `trip_detail` |

   未註冊的 path 會落到既有的 `errorBuilder` → `RedirectToHome`，
   所以殘留的 deep link 自動導回首頁，不會出現錯誤頁。

### 保留不動

`features/journey/`、`features/trip/` 整個模組、既有測試
（`journey_screen_test.dart`、`trip_bookshelf_test.dart` 等），以及 narration
播放完把記錄寫進 journey / trip 的邏輯。**記錄照存，只是使用者暫時看不到入口**
——這是刻意的，flag 改回 `true` 時歷史資料仍在。

### 測試

- `home_top_bar` widget test：`kBookshelfEnabled` 為 false 的現況下，
  找不到 `Key('home-open-journey')`。
- router test：導向 `/journey` 會落到 `RedirectToHome`（首頁）。

## 設計 B：故事導覽存 DB

完全比照既有的鉤子快取，包含它的失敗策略：**快取絕不能弄壞 API**——讀寫都吞
例外並 log，讀失敗就當 miss、正常生成；只存成功結果，所以某次失敗的景點日後
仍可能成功。

### 快取 key

`(place_key, language, hook_id)`：

- `place_key` 沿用既有的 `place_key_for(request)`——Wikidata Q-id，或舊路徑的
  `title:<wikipedia_title>`。
- `hook_id` 取 `request.hook.id`；`request.hook` 為 `None` 時用空字串 `''`
  （代表「不經鉤子直接生成」那條路徑）。

同景點同語言選同一個鉤子 → 拿到一模一樣的故事；換鉤子 → 是另一篇新故事，
與「選鉤子 → 生成」的 UX 一致。

### Migration

`supabase/migrations/20260811000000_create_narration_cache.sql`：

```sql
CREATE TABLE IF NOT EXISTS public.narration_cache (
  place_key TEXT NOT NULL,
  language  TEXT NOT NULL,
  hook_id   TEXT NOT NULL,   -- '' = 無鉤子（直接生成）的路徑
  narration JSONB NOT NULL,  -- 整個 NarrationResponse
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (place_key, language, hook_id)
);

ALTER TABLE public.narration_cache ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.narration_cache TO service_role;
```

RLS 開啟但不給任何 policy——App 端（anon / authenticated）完全碰不到，
service role 繞過 RLS。

**權限與建表寫在同一份 migration**：鉤子那張表就是因為 grant 漏寫、拖到一個月
後才用 `20260705120001` 補上，期間每次請求都在重新生成（見該檔註解）。

### 後端改動

- `backend/src/lorescape_backend/narration/cache.py`
  新增 `NarrationCacheRepository`：
  - `get(place_key, language, hook_id) -> NarrationResponse | None`
  - `put(place_key, language, hook_id, result) -> None`
  - `hook_id_for(request) -> str` 輔助函式。
- `backend/src/lorescape_backend/narration/dependencies.py`
  新增 `get_narration_cache_repository`（測試可 override）。
- `backend/src/lorescape_backend/narration/routes.py` 的 `post_narration`：
  先查快取，命中直接回傳；未命中則生成後 `put`。
  只在 `insufficient_source` 為 false 且 `paragraphs` 非空時寫入。

### 不做

- TTL 或主動失效機制（與鉤子一致；要重生就手動刪 row）。
- 前端不動——快取完全在後端，App 無感。

### 測試

`backend/tests/narration/test_cache.py` 與 `test_routes.py` 比照鉤子的既有案例
補上：

- 命中快取：不呼叫 `generate_narration`，回傳存的內容。
- 未命中：生成並寫入。
- 讀取拋例外：降級為生成，端點不失敗。
- 寫入拋例外：端點照常回傳結果。
- `insufficient_source=True` 或 `paragraphs` 空：不寫入。
- 不同 `hook_id` 各自獨立快取；`hook=None` 對應 `hook_id=''`。

## 驗收

- `cd frontend && fvm flutter analyze --fatal-infos` 無問題。
- `cd frontend && fvm flutter test` 全綠。
- `cd backend && uv run pytest` 全綠。
- App 首頁看不到書架按鈕；手動導向 `/journey` 會回首頁。
- 同景點同鉤子連續生成兩次，第二次不打 Gemini（後端 log 有 cache hit）。
