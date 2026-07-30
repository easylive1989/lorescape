# ADR 0005：探索頁地圖的 tile provider 選型

- 狀態：Accepted（2026-07-21 當日修訂一次，見文末「決策修訂紀錄」）
- 日期：2026-07-21
- 影響範圍：`frontend/`（新增 `flutter_map` + `vector_map_tiles` 依賴、探索頁）、
  BACKLOG F17
- 相關：`docs/design/project/app2/screens_explore.jsx`（v2 設計稿）

## 背景

F17 要把探索頁從直式地點列表改成**全螢幕世界地圖**（設計稿見
`docs/design/README.md` 的 v1→v2 差異表）。App 目前完全沒有地圖套件，
`pubspec.yaml` 只有 `geolocator`。

設計稿是 Leaflet 原型，底圖直接指向 `tile.openstreetmap.org`。**這條路不能
照抄進生產**：OSM 官方的
[Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
明文要求「有顯著用量的應用必須自架 tile server 或改用第三方服務」，並且
會**不另行通知直接封鎖**違規的 app。已有多個 app 因此被擋。所以在寫任何
地圖程式碼之前，得先把 tile 來源定下來。

Lorescape 的處境有三個約束值得寫下來：

1. **這是商業 app**（訂閱制），所以「免費方案僅限非商業用途」的服務全部
   出局——這一條刷掉了最常被推薦的兩家。
2. **目前幾乎沒有流量**（2026-07 週報：App 週活躍 22 人、iOS 下載 2/週），
   同時也**幾乎沒有營收**。固定月費對現階段是實質成本。
3. **F17 本質是設計還原**。底圖不只是功能，是視覺的一部分——設計稿的暖色
   紙感（`--paper` / `--clay` 色票）需要底圖配合，這會影響 raster / vector
   的選擇權重。

## 選項評估

| 方案 | 費用 | 商業使用 | tile 型態 | 用量天花板 |
|---|---|---|---|---|
| **OpenFreeMap 公共實例** | $0 | ✅ 明確允許、無 API key | vector | **無上限** |
| Geoapify Free | $0 | ✅ 明確允許 | raster | 3,000 credits/日、5 req/s |
| Stadia Maps Starter | $20/月 | ✅ | raster + vector | 1M credits/月 |
| MapTiler Flex | $30/月 | ✅ | vector | 25k sessions/月；強制 logo |
| 自架 Protomaps pmtiles（R2） | ~$3/月 | ✅ 完全自主 | vector | 無上限 |

**Stadia 與 MapTiler 的免費方案都明文禁止商業使用**（"Commercial use not
allowed" / "suitable for testing, personal or non-commercial use"），訂閱制
App 直接不可用，入門價分別是 $20 與 $30/月。

## 決策

**採用 OpenFreeMap 公共實例，走 vector tiles，以
`flutter_map` + `vector_map_tiles` 渲染。**

理由：

- **零成本且無用量天花板**。相對的，Geoapify 免費方案是 3,000 credits/日、
  5 req/s——以每次開圖十幾片 tile 估，天花板大約是每天數百次開圖。現在的
  流量遠低於此，但這是個會隨成長撞到的牆，而 Geoapify 的下一階要 $59/月。
- **無 API key**。這對 client-side app 是實質優點：打包進 mobile app 的 key
  本來就可被萃取，少一個要管、要輪替、要藏進 `.env` 的秘密。
- **樣式完全可控，這是選 vector 的決定性理由。** OpenFreeMap 提供
  style JSON（liberty / positron / bright / dark / fiord），
  `vector_map_tiles` 可用 `ThemeReader().read(styleJson)` 吃任意 MapLibre
  樣式。也就是說底圖配色能**真的**照 field journal 色票調，而不是拿別人的
  底圖蓋一層 sepia 濾鏡假裝。F17 是設計還原工作，這點的份量高於省下的
  工程時間。
- **schema 相容性有把握**：OpenFreeMap 用的是
  **unmodified OpenMapTiles schema**，正是 `vector_map_tiles` 已驗證的
  provider 家族（Mapbox / Stadia / MapTiler 皆同源）。
- **逃生路線是同一套技術棧**：若 OpenFreeMap 哪天不穩或消失，改成自架
  Protomaps pmtiles（~$3/月）只是換 tile provider 與樣式，渲染層不動。

### 相依版本

`vector_map_tiles` **9.0.0-beta.9**（相依 `flutter_map: ^8.1.1`，
發布於 2026-05 底）。維護者明白建議：正式 app 用 `8.0.0` 或
`9.0.0-beta.8`；`10.0.0-beta` 相依 `flutter_gpu` 與 Flutter dev channel，
**不可用於生產**。

## 風險

vector 路線的代價集中在**渲染效能**：`vector_map_tiles` 是 Dart 端繪製，
比 raster 重。[Issue #120](https://github.com/greensopinion/flutter-vector-map-tiles/issues/120)
（2023 年開、現已關閉）曾回報「低階裝置上幾乎不可用」。

**使用者決定（2026-07-21）：不做效能 spike，也不保留 raster 退路，直接
實作 vector。** 承擔的風險是低階裝置上的縮放/平移可能不順，且沒有預先
驗證過。若日後真的在實機上發現不可接受的卡頓，再回頭評估
Geoapify Free + raster（見「未採納但保留的選項」），但那將是一次新的決策，
不是本 ADR 預留的自動退路。

其他要注意的：

- **Attribution 是義務不是選配**：必須顯示
  `OpenFreeMap © OpenMapTiles Data from OpenStreetMap`。做法變更過兩次：

  1. 最初是地圖右下角的文字角標。
  2. 2026-07 改為探索頁頂部 icon 列裡的一顆 ⓘ 按鈕。
  3. 2026-07-30 改回角標，並在設定頁另加一份完整說明（現行做法）。

  現行做法是兩份並存，**兩份都不得移除**：

  - **地圖右下角的文字角標**（`LorescapeMap._AttributionBadge`）——OSM
    attribution guideline 要求署名要能從地圖上直接可及，這一份就是那個義務。
    角標畫在 `LorescapeMap` 內而非呼叫端，任何用到這張底圖的畫面都會自動帶
    著署名。呼叫端若在地圖上疊了貼底的浮層，**必須**確保角標不被蓋掉——用
    `attributionBottomInset` 把角標推到浮層上方，或確保浮層下方留有角標放
    得下的透空縫隙（2026-07-30 起探索頁走後者：角標在地點卡片列下方的縫隙，
    卡片列 ListView 的底部內距保證卡片不會壓到它）——署名被蓋掉等同沒有
    署名。
  - **設定頁的「地圖資料來源」**（`_MapSourceGroup`）——完整出處與
    openstreetmap.org/copyright 連結。

  之所以從 ⓘ 改回角標：ⓘ 佔掉探索頁頂部 icon 列一個位置，而該列在 v3 導覽
  重組後還要放地球儀返回鈕；角標是 OSM 最標準的做法，且不佔互動元素的位置。
- **beta 相依**：`9.0.0-beta.9` 要在 `pubspec.yaml` 釘死確切版本，不用
  caret range，避免 beta 之間的破壞性變更無聲進來。
- **無 SLA**：OpenFreeMap 由單一維護者以捐款支撐專用主機。這是接受的風險，
  緩解手段是上面的 pmtiles 逃生路線。
- **禁用預抓取**：OSM 政策禁止 bulk download / 離線預抓，探索頁不得實作
  「下載此區域離線使用」這類功能。

## 未採納但保留的選項

- **Geoapify Free + raster**：正式的 plan B，效能 spike 不過就走這條。
- **自架 Protomaps pmtiles on Cloudflare R2**：整份 planet basemap 約
  115–120 GB，R2 儲存約 $2–3/月且無流量費。要完全脫離第三方時的最終形態。

## 決策修訂紀錄

本 ADR 初稿（同日）選的是 **Geoapify Free + raster**，理由寫的是
「OpenFreeMap 只有 vector，而 `vector_map_tiles` 穩定版相依
`flutter_map ^7.0.2`、落後現行 8.3.1 一個 major，得把 flutter_map 釘死在
7.x」。

**這個理由是錯的。** 使用者質疑後重新查證：`vector_map_tiles` 的
`9.0.0-beta.9` 相依 `flutter_map: ^8.1.1`、發布於 2026-05 底，套件仍在積極
維護；根本不需要把 flutter_map 釘在 7.x。初稿只看了 pub.dev 上的「穩定版
23 個月前」就下結論，沒有去查 beta 線的相依。

錯誤前提移除後，vector 的三個實質優點（無用量上限、無 API key、樣式完全
可控）沒有對應的成本可抵銷，因此改採 OpenFreeMap。原方案降為 plan B。

## 參考

- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
- [OpenFreeMap](https://openfreemap.org/)
- [`vector_map_tiles`](https://pub.dev/packages/vector_map_tiles) / [9.0.0-beta.9](https://pub.dev/packages/vector_map_tiles/versions/9.0.0-beta.9) / [issue #232 flutter_map v8 support](https://github.com/greensopinion/flutter-vector-map-tiles/issues/232)
- [`flutter_map`](https://pub.dev/packages/flutter_map)
- [Geoapify Pricing](https://www.geoapify.com/pricing/)
- [Stadia Maps Pricing](https://stadiamaps.com/pricing/)
- [MapTiler Cloud Pricing](https://www.maptiler.com/cloud/pricing/)
- [Protomaps Cost Calculator](https://docs.protomaps.com/deploy/cost)
