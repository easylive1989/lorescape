# 產品數據單頁設置

`dashboard/` 把 `data/metrics/*.csv` 整形後**內嵌**成一支無框架、無相依的
單檔 HTML（`dashboard/out/metric.html`）。不部署、不上傳、不需憑證。

> **2026-08-10 改版**：原本是 uv 套件（`lorescape-dashboard`），會收集
> backlog / 測試 / 部署 / 每日故事 / Reels 排程等多個區塊並產生
> `out/index.html`，另有 `--serve` 即時模式。該版本已移除，只保留產品數據。
> 其他區塊之後有需要再獨立做。

## 前置

- 需要 Python 3（純標準函式庫，無第三方相依，不需要 uv、不需要 `.env`）
- `data/metrics/*.csv` 要先有資料——由 **lorescape-metrics** skill 累積

## 執行

```bash
python3 dashboard/build_metric.py
```

產出 `dashboard/out/metric.html`（gitignored），雙擊即可離線開啟，也能直接
傳給別人。

## 為什麼要重跑指令，不是打開就自動更新

`file://` 下瀏覽器的 CORS 政策會擋掉 `fetch()` 讀本機 CSV，純靜態單檔沒辦法
在開啟時才去讀資料夾。折衷是**建置時把資料內嵌**，要看最新數據就重跑一次
（約 0.1 秒）。頁首標了資料截止日與建置時間，不會把舊快照誤當即時數據。

若真的想要「打開就是最新」，得改用 `python3 -m http.server -d dashboard/out`
之類的本機伺服器 + `fetch` 讀 CSV——代價是每次要先啟動伺服器，且單檔傳出去
會是空的。目前選擇內嵌。

## 內容

KPI 列（本週 vs 前週）、IG 每日觸及、粉絲累積、Reels vs Carousel 觸及
（對數刻度）、Reels 24h 略過率（依 calendar 的謎/閉 style 上色）、週漏斗、
App / Landing 每日活躍、各來源資料新鮮度。每張圖有 hover tooltip，主要圖表
另附表格檢視。

謎/閉 style 由 `marketing/content-calendar/_reels-place-calendar.md` 解析，
表格第 5 欄與「style 排程」散文兩種寫法都支援。

## 檔案

| 檔案 | 用途 |
|---|---|
| `dashboard/build_metric.py` | 讀 CSV → 整形 → 把 JSON 注入模板 |
| `dashboard/metric_template.html` | 版面、CSS token、SVG 繪圖；`/*__DATA__*/null` 為注入點 |
| `dashboard/out/metric.html` | 產出物（gitignored） |
