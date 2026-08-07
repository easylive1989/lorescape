# 《千日之後》素材生成待辦

## 現況

`story/public/content/tower-of-london-anne/assets/` 底下的 8 張場景圖與 3 位角色
（各 4 部件 + `_reference.png`）目前是**佔位圖**，由 Pillow 現場產生的色塊 +
簡易剪影（漸層背景 + 幾何形狀示意場景與角色輪廓），不是 Gemini 生成的正式插畫。

**原因**：`gemini-2.5-flash-image` 模型在目前 `GEMINI_API_KEY`（`publisher/.env`，
與 `backend/.env` 共用同一把）所屬的 Google AI Studio / Cloud 專案免費層配額為
0（`429 RESOURCE_EXHAUSTED ... limit: 0`），需要該專案啟用計費（billing account）
才有配額可用。BGM（`assets/audio/main.mp3` + `SOURCES.md`）不受影響，已是正式素材。

## 配額開通後的生成步驟

1. 確認 `publisher/.env` 的 `GEMINI_API_KEY` 所屬專案已啟用計費。
2. 若本機 shell 環境變數同時有 `GOOGLE_API_KEY`（例如其他工具設定的），
   google-genai SDK 會優先採用它而非 `GEMINI_API_KEY`，執行前記得
   `unset GOOGLE_API_KEY`，否則會打到錯的專案/配額。
3. 在 `scripts/` 目錄執行（**既有佔位檔案要加 `--force` 才會覆蓋**）：

   ```bash
   cd scripts
   uv run python story_assets_gen.py scenes --slug tower-of-london-anne --force
   uv run python story_assets_gen.py characters --slug tower-of-london-anne --force
   uv run python story_assets_gen.py check --slug tower-of-london-anne
   ```

   單張重生可用 `--only`，例如：
   `--only scenes/thames-wharf-night.png --force`、
   `--only anne:head --force`。

4. 生成後逐張人工過目（畫面完整、無文字浮水印、內容對應 art.json 的 prompt、
   直式構圖；角色 `_reference.png` 先確認風格貼近使用者參考圖再看部件去背是否
   乾淨、無洋紅殘留）。
5. `check --slug tower-of-london-anne` 需 exit 0，`cd story && npm run build` 需綠。
6. **正式圖生成、驗收通過後，刪除本檔案**（`story/ASSET-GENERATION-TODO.md`）
   並在 commit 訊息中說明「佔位圖 → 正式圖」。

## 待生成清單

### 場景（8 張，900×1600，直式，風格見 art.json `style` 欄位）

| rel_path | art.json prompt 摘要 |
|---|---|
| `scenes/greenwich-privy-chamber.png` | 格林威治王后寢殿，四柱床、緋紅帷幔、鑲鉛玻璃窗、午後斜陽，無人 |
| `scenes/thames-wharf-night.png` | 泰晤士河夜間碼頭，遠方倫敦塔剪影與火把倒影、薄霧、殘月，無人 |
| `scenes/seymour-wardrobe.png` | 都鐸衣物間，開啟的旅行箱、掛袍、清冊與秤，高窗一道光束，無人 |
| `scenes/tower-constable-room.png` | 倫敦塔典獄官石室，鐵鑰匙串、火漆信件、箭孔窗，無人 |
| `scenes/queens-lodging-tower.png` | 塔內王后居所，黑白棋盤地磚、天篷床、燭台、冷石牆，無人 |
| `scenes/lodging-door-corridor.png` | 王后居所外石廊，厚重橡木門下透出燭光縫隙，深夜，無人 |
| `scenes/tower-green-dawn.png` | 塔綠地黎明，霜、簡易木台（無斬首器具）、白塔背景、稀疏遠景群眾，無人 |
| `scenes/london-street-1559.png` | 1559 年 1 月倫敦雪街，木構屋簷、彩旗、遠方加冕遊行剪影 |

完整 prompt 見 `story/public/content/tower-of-london-anne/art.json` 的 `scenes` 欄位。

### 角色（3 位 × 4 部件 + reference，去背 RGBA PNG）

| id | art.json prompt 摘要 | parts（script.json 定義路徑） |
|---|---|---|
| `anne` | 安妮・博林，深栗紅絲絨袍、黑新月法式頭飾、珍珠 B 字項鍊 | `characters/anne/{head,torso,left-arm,right-arm}.png` |
| `kingston` | 威廉・金斯頓爵士，倫敦塔典獄官，灰鬚、深炭色毛領長袍、鐵鑰匙串 | `characters/kingston/{head,torso,left-arm,right-arm}.png` |
| `thomas` | 湯瑪士・奧爾德，王室侍從，都鐸綠白號衣、皇家徽章 | `characters/thomas/{head,torso,left-arm,right-arm}.png` |

完整 prompt 見 `art.json` 的 `characters` 欄位；生成流程見
`scripts/story_assets/characters.py`（先生 `_reference.png` 全身參考圖，
再以此為參考生四部件並用洋紅去背）。

## 驗收要點

- 風格與 art.json 的 `style` 描述一致（cel-shaded、粗墨線、都鐸配色、單一暖光源）。
- 直式構圖 900×1600，畫面下三分之一保持相對簡潔（要疊角色與文字卡）。
- 角色部件去背乾淨，無洋紅殘邊；四部件比例與風格一致（同一參考圖生成）。
- 無文字、浮水印、簽名。
