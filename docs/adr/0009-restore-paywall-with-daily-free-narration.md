# ADR 0009：恢復付費牆，非訂閱者每日免費一篇導覽

- 狀態：Accepted
- 日期：2026-08-19
- 影響範圍：backend `narration` route、frontend router + settings + narration、
  Supabase `daily_usage`

## 背景

ADR 0006（2026-08-05）為了 v3 改版鋪路，把付費牆整組拔掉，`POST /narration`
不再回 402，App 全面免費。v3 設計定案後決定恢復收費，但不回到「訂閱才能
用」的舊模式——改成非訂閱者每天可以免費生成一篇導覽，超過額度才擋到付費
牆。這個規則同時也是把 ADR 0006 附錄的死碼清單往前推進一步的機會：清單裡
有幾項當初刻意保留的程式碼，這次改版正好用得上。

## 決策

擋點恢復在 `POST /narration`（`backend/src/lorescape_backend/narration/routes.py`
的 `post_narration`）：

1. `is_premium = subscriptions.is_subscribed(user.user_id)`。
2. 非 premium 且 `not has_free_quota(usage.used_today(user.user_id))` → 回
   402，detail `"Daily free quota exhausted"`。
3. 查快取；命中直接回傳快取結果。
4. 未命中才呼叫 `service.generate_narration`；失敗（拋例外）直接往外拋，
   不繼續往下走。
5. 快取命中或生成成功後，非 premium 使用者呼叫 `usage.consume(user.user_id)`。

額度常數 `DAILY_FREE_LIMIT = 1` 與判斷函式 `has_free_quota(used_today)` 放在
`backend/src/lorescape_backend/usage/policy.py`，不放進資料庫——用意是讓額
度是單一、應用程式自有的常數，之後要調整不必跑 migration。

**額度檢查排在查快取之前，且快取命中一樣消耗額度。** 這是刻意的產品規
則：「一天一篇故事」，不是「一天一次 Gemini 呼叫」。如果快取命中不算消
耗，使用者只要專挑熱門景點（快取早已存在）就能無限免費看故事，訂閱的誘因
就被架空了。反過來，生成失敗（例如上游服務出錯）不消耗額度——使用者沒拿
到東西，不該算在他頭上。

`POST /narration/hooks` 維持免費，不檢查也不消耗額度。

Supabase 端沿用既有的 `daily_usage` 表與 `get_daily_used_count` /
`consume_free_usage` 兩支 RPC（migration `20260601000001_recreate_daily_usage.sql`），
本次未新增 migration。

### 前端

402 直接導向付費牆，不做任何前置擋、不顯示剩餘次數：

- `router_config.dart` 恢復 `/subscription` route。
- 設定頁最上方恢復升級卡片，點擊 push `/subscription`。
- `narration_api_client.dart` 既有的 402 → `NarrationError.freeQuotaExceeded`
  映射、`narration_generation_controller.dart` 的
  `freeQuotaExceeded → NarrationGenerationErrorType.quotaExceeded` 都是 ADR
  0006 時代就留著的半保留契約，這次直接重用；產生導覽的畫面收到
  `quotaExceeded` 時 `context.push('/subscription')`，不彈錯誤訊息、不跳廣
  告對話框。
- App 端不再做任何本地額度計數：`features/usage/` 整包刪除（見下）。額度
  的唯一真實來源是 backend，App 完全不追蹤剩餘次數。

## 消化掉的 ADR 0006 死碼清單

ADR 0006 附錄列了幾項「刻意保留的死碼」作為未來調整付費模式時的盤點起
點。這次改版消化掉其中四項：

- `features/usage/`（frontend 本地額度計數器）：整包刪除，包含
  `create_narration_use_case.dart` 對 `UsageRepository` 的依賴與
  `consumeUsage()` 呼叫、`narration/providers.dart` 對 usage providers 的引
  用、`narration_generation_controller.dart` 的 `UsageError` 分支。這個計數
  器本來就只寫 SharedPreferences、從不拋錯、擋不住任何東西，是純粹的
  vestigial code，清單上標注它「不是可獨立刪除的孤立模組」在這次改版中已
  不成立——因為新流程根本不需要它。
- `/subscription` 路由：已恢復註冊。
- 設定頁升級入口：已恢復。
- HTTP 402 契約：`narration_api_client.dart` 的 402 映射重新被實際觸發，不
  再是「半保留的舊契約」。

清單上仍未處理、留給未來的：

- backend `subscriptions/` 模組本身沒動（RevenueCat webhook、每日 03:00
  reconcile job），這次只是重新讓 `narration/routes.py` 呼叫它。
- `main.dart` / `app.dart` 的 RevenueCat SDK 初始化與 `logIn` 從 ADR 0006 起
  就沒停過，這次也沒有變動。
- App Store / Play 商店端訂閱商品與 RevenueCat offering 不動，本次只換付費
  牆視覺，方案與定價沿用既有 offering。

`docs/adr/0006-temporarily-remove-paywall.md` 的狀態改為
`Superseded by ADR 0009`。

## 影響與注意事項

- 現有訂閱者（如果之後累積出現）不受額度限制，`is_subscribed` 判斷優先於
  額度檢查。
- 402 回應沒有帶剩餘額度或重置時間等資訊，前端也不解析——維持「不顯示剩
  餘次數」的產品決定，額度用完的當下錯誤訊息完全省略，直接開付費牆。
- 相關 spec：`docs/superpowers/specs/2026-08-19-redesign-v3-design.md` 第五
  節。
