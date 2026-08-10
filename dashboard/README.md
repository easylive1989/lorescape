# dashboard — 產品數據單頁

把 `data/metrics/*.csv`（由 lorescape-metrics skill 累積）整形後，**內嵌**成
一支無框架、無相依的單檔 HTML。

```bash
python3 dashboard/build_metric.py     # → dashboard/out/metric.html
```

雙擊 `out/metric.html` 即可離線開啟，也能直接傳給別人。

## 為什麼是「重建」而不是「打開就自動更新」

`file://` 下瀏覽器的 CORS 政策會擋掉 `fetch()` 讀本機 CSV，所以純靜態單檔
沒辦法在開啟時才去讀資料夾裡的 CSV。折衷是**建置時把資料內嵌**：要看最新
數據就重跑一次上面的指令（約 0.1 秒）。頁首會標出資料截止日與建置時間，
不會讓人誤把舊快照當成即時數據。

## 檔案

| 檔案 | 用途 |
|---|---|
| `build_metric.py` | 讀 CSV → 整形 → 把 JSON 塞進模板（純標準函式庫，無第三方相依） |
| `metric_template.html` | 版面、CSS token 與 SVG 繪圖；`/*__DATA__*/null` 是資料注入點 |
| `out/metric.html` | 產出物（gitignored） |

## 內容

KPI 列（本週 vs 前週）、IG 每日觸及、粉絲累積、Reels vs Carousel 觸及
（對數刻度）、Reels 24h 略過率（依 calendar 的謎/閉 style 上色）、週漏斗、
App/Landing 每日活躍、各來源資料新鮮度。每張圖都有 hover tooltip，主要圖表
另附表格檢視。

謎/閉 style 由 `marketing/content-calendar/_reels-place-calendar.md` 解析
（表格第 5 欄與「style 排程」散文兩種寫法都吃）。

配色沿用 dataviz 規範的驗證過調色盤，light/dark 各自成立。
