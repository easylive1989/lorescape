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
