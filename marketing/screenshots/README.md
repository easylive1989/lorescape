# Lorescape — App Store / Google Play 截圖

由 `app-store-screenshots` skill 產出的行銷截圖（廣告式，非 UI 展示）。

- **風格**：Retro Rubberhose Mascot（1930s 卡通 / Cancoco 風）——暖色純色背景（cream / mustard / pink / sage mint）＋紙質顆粒、**奶油色手機外框＋粗黑墨描邊**、左上小寫浮雕 `lorescape` wordmark、Cooper 風 chunky 標題 + 一句珊瑚色重點字＋手繪波浪底線、橡皮管罐頭吉祥物（圓眼／白手套／揮手）、墨點塗鴉。
- **語言**：繁體中文、English。
- **裝置**：Apple App Store（iPhone 4 尺寸）、Google Play（手機 + Feature Graphic）。
- **可切換風格**：每張 slide 的 `style` 欄位可選 `"retro"`（目前）或 `"hand-drawn"`（先前的 Superlist 深色版，程式碼仍保留）。先前的 hand-drawn 與更早的 warm-editorial 版本都在 git 歷史中。

> ⚠️ **iCloud 注意**：本 repo 位於 `~/Documents`，受 iCloud Drive 同步。在這裡 `bun install`（產生數十萬個 node_modules 檔案）會觸發 iCloud 清掉本機檔案。**請勿在 repo 內安裝／執行 Next 編輯器**。可執行的編輯器放在 iCloud 外：`~/lorescape-screenshots-editor`。

## 目錄

```
export/                         # ← 最終截圖（可直接上架）
  ios/iphone/<尺寸>/<locale>/NN-device-bottom.png
  android/android/1080x1920/<locale>/NN-...png
  android/feature-graphic/1024x500/<locale>/01-feature-graphic.png
editor/                         # 編輯器原始碼快照（不含 node_modules，僅供版控/重生）
  app-store-screenshots.json    # deck 設定（文案、背景色、吉祥物、塗鴉…）
  src/components/editor/retro.tsx       # Retro 風格渲染（奶油框、吉祥物、顆粒、塗鴉）
  src/components/editor/hand-drawn.tsx  # 先前 hand-drawn 風格（保留）
  capture/_capture.{html,mjs}   # 高解析重截 app 畫面的工具
```

iPhone 尺寸：`1320x2868`=6.9"、`1284x2778`=6.5"、`1206x2622`=6.3"、`1125x2436`=6.1"。
上架時每個顯示尺寸群組擇一即可（通常 6.9"+6.5"）。

## 五張截圖

| # | 背景 | 文案（chunky + 珊瑚重點） | 畫面（Redesign v3）| 吉祥物 |
|---|---|---|---|---|
| 1 | cream | 讓每一處風景 ·*開口說故事* | 首頁地球儀 + 每日故事卡片 | 黃罐頭 |
| 2 | mustard | 同一個地方 ·*不只一個故事* | 故事角度選擇（想聽哪段故事?）| 蜜桃 |
| 3 | pink | 聽 AI 為你 ·*娓娓道來* | 閱讀頁 + 語音播放列 | 赭紅 |
| 4 | sage mint | 發現方圓內 ·*身邊的風景* | 探索地圖（定位模式）| 黃罐頭 |
| 5 | cream | 走過的地方 ·*自動成冊* | 歷程書架 | 蜜桃 |

> 素材為 **Lorescape Redesign v3**（globe home + detail map）。手機內畫面由
> `docs/design/project/` 的 v3 原型以 4× 重截，harness 見
> `editor/capture/_capture_v3.html`（screen=home|hooks|reader|map|history）。

## 重新產生

1. 把編輯器複製到 iCloud 外（首次）：
   ```bash
   cp -R marketing/screenshots/editor ~/lorescape-screenshots-editor
   cd ~/lorescape-screenshots-editor && bun install
   ```
2. 啟動編輯器調整文案／版面／配色：
   ```bash
   bun dev   # → http://localhost:3000，調整後按 Export bundle（下載 zip）
   ```
3. 把匯出的 zip 解壓回 `marketing/screenshots/export/`。
4. 改完記得把 `~/lorescape-screenshots-editor` 的 `app-store-screenshots.json` 與
   `src/` 改動同步回 `marketing/screenshots/editor/`。

### 高解析重截 app 畫面（素材）

截圖素材（無外框純畫面）在 `editor/public/screenshots/lorescape/*.png`，由
`docs/design/project/` 的 React 設計原型以 4× 重截。

**v3（現行）**：用 `capture/_capture_v3.html`，screen 參數為
`home|hooks|reader|map|history`。地圖畫面需要網路（OSM 磚圖），地球儀需要
d3 + world-atlas CDN。

舊版（v1 原型）重截：

```bash
cp marketing/screenshots/editor/capture/_capture.* /tmp/ls-proto/   # /tmp/ls-proto = docs/design/project 的複本
cd /tmp/ls-proto && python3 -m http.server 8899 &
node _capture.mjs   # 需要全域 playwright；輸出到 ~/lorescape-screenshots-editor/public/...
```

## 實作備註

- Retro 風格渲染在 `editor/src/components/editor/retro.tsx`（奶油手機框 `RetroPhone`、
  橡皮管吉祥物 `Mascot`、紙質顆粒、墨點塗鴉、Cooper 風標題）＋ `slide-canvas.tsx` 的
  `style === "retro"` 分支。每張 slide 的 `bgColor / scriptPhrase / scriptColor / mascot /
  tilt` 在 `app-store-screenshots.json` 設定。
- 字體：標題用 Lilita One（Cooper Black 替代，英文）＋ Noto Sans TC 900（中文 chunky）。
- 匯出用 `skipFonts`（CJK 大字檔會讓 html-to-image 卡死）；英文重點字呈現真正的 Cooper／
  cursive，中文由系統 chunky 字渲染。
- 依你的指示採用**奶油色手機外框**（spec 後段雖改用黑框，但以你的指示為準）。
- 此 App 為暖色亮系 UI，無深色版可截，故手機內維持實際畫面（風格其餘元素完整套用）。
