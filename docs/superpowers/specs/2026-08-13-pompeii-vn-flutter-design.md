# 龐貝景點包：Flutter 視覺小說引擎

> **後記（2026-08-14）**：專案目錄最終定名為 `story/`（本文件寫作時暫稱 `vn/`），Dart package 為 `lorescape_story`。素材格式最終採用 WebP（143 MB → 8 MB，alpha 無損），非本文件 §決策 5 所寫的 PNG。


**日期**：2026-08-13
**範圍**：新增 `vn/`（獨立 Flutter 專案，先跑 Flutter Web 驗證）；移除 `story/`（Vite + React SPA）
**內容來源**：`writer/創作/龐貝/`（不進版控的 Obsidian vault，8 篇 `story.json` + 60 張美術）

## 問題

`writer/創作/龐貝/` 已經備齊一整個景點包的內容與美術：8 篇群像短篇、73 場、2,380 節點、34,174 字、24 個結局、60 張直式美術，八篇 `story_tool.py check` 全部通過零警告。但**沒有任何東西能播放它**。

repo 裡現有的播放器是 `story/`（React SPA），它讀的是另一套 `script.json` 格式，能力落後新內容一個世代：

| 新內容需要 | `story/` 現況 |
|---|---|
| 數值變數（16 個宣告變數，`>=` / `==` 條件） | 只有 boolean flag |
| 場（scene）層級：`background` / `bgm` / `next` / `isEnding` | 只有扁平節點清單 |
| 立繪表情切換（44 張差分，`d.sprite` 用了 179 次） | 一角色一張圖 |
| `if` / `then` 巢狀節點、`option.then`、`option.branch` | 選項只能 `to` 一個節點 |
| `cg` 全螢幕、`sfx`、`bgm` 節點 | 無 |

而最終載體是 Flutter（`Flutter製作規範` 是實作端唯一規格來源），`story/` 的 React 實作搬不過去。

## 決策

以下五項在設計討論中定案，是本規格的前提：

1. **載體 = Flutter**，不繼續用 React。先跑 **Flutter Web** 驗證，確認後搬進 `frontend/`（Lorescape App）。
2. **獨立專案 `vn/`**，不直接寫進 `frontend/`。但**程式結構必須是一包能整包搬進 `frontend/lib/features/visual_novel/` 的模組**。
3. **8 篇一次到位**，不做單篇垂直切片。
4. **`story/` 整個刪掉**，含兩篇舊劇本（`pompeii-bakery`、`tower-of-london-anne`）、引擎、`/editor` 工作台與 `plugins/editor-api/`。
5. **不轉 WebP**。開發期直接用 PNG（`Flutter製作規範` §4.1 本來就把轉檔排在送審前）。

## 非目標

- **不做音訊。** 26 個 `sfx` id、15 個 `bgm` id 全部不存在，整包無聲。引擎照 `missingAssets` 靜音降級，留介面但不接播放套件。
- **不做購買與解鎖。** `Flutter製作規範` §5.8 的景點包買斷／訂閱，等搬進 `frontend/` 再接既有的 RevenueCat。
- **不做編輯器。** 劇本的唯一來源是 `writer/` 的 `story.json`，校稿走 `story_tool.py check` / `render`。
- **不改劇本內容。** `story.json` 逐字複製進 `vn/assets/`，一個字不動。
- **不做英文版。**

## 內容盤點（實測，非估算）

```
節點型別：n 1718 / d 362 / show 50 / sfx 50 / choice 40 / hide 38 / if 26 / add 5 / set 3 / cg 3 / bgm 1
場欄位：  title 73 / background 73 / bgm 73 / nodes 73 / next 41 / isEnding 24 / endingId 24
選項欄位：text 84 / then 64 / add 49 / goto 15 / branch 5 / set 4 / cond 4
條件運算：>= 25 / == 6
```

| # | 篇 | id | 副標 | 場 | 變數 |
|---|---|---|---|:-:|---|
| 1 | 港口的外地人 | `pompeii_01_harbour_stranger` | 爆發前一日 | 12 | affection / awareness |
| 2 | 烤爐熄了 | `pompeii_02_the_oven_went_out` | 爆發當日清晨 | 10 | pride / ties |
| 3 | 井水退了 | `pompeii_03_the_well_fell` | 徵兆時分 | 8 | conviction / standing |
| 4 | 天上那棵樹 | `pompeii_04_the_tree_in_the_sky` | 噴發柱升起 | 10 | obedience / bonds |
| 5 | 蠟板 | `pompeii_05_the_tablets` | 浮石雨中段 | 9 | loyalty / self |
| 6 | 上鎖的門 | `pompeii_06_the_locked_door` | 浮石雨深夜 | 8 | nerve / kinship |
| 7 | 靠不了岸 | `pompeii_07_cannot_land` | 同一夜・海上 | 8 | duty / witness |
| 8 | 普特奧利的新房子 | `pompeii_08_the_new_house` | 災後數月 | 8 | roots / memory |

每篇 3 個結局（A/B/C），共 24 個。

### 規範沒寫、但資料在用的三件事

`Flutter製作規範` §3.3 的表格漏了這些，實作必須支援，否則會在執行期炸掉或默默走錯分支：

| 欄位 | 用量 | 位置 | 語意 |
|---|:-:|---|---|
| `option.cond` | 4 | 02/S07、04/S07、05/S06、08/S05 | **條件選項**——`cond` 不成立時該選項不顯示 |
| `show.filter` | 1 | 08/S04（`"memory_desaturate"`） | 立繪套濾鏡（回憶去飽和） |
| `bgm` 節點的 `id: null` | 1 | | 停止 BGM |

另外，**6 個變數從未宣告卻被條件參照**：`deal` / `bread` / `spoke` / `hideout` / `boy` / `told`。它們由 `set` 節點與 `option.set` 寫入字串或布林值。依 §3.3「未宣告的變數視為 `null`／`false`」處理——這不是資料錯誤，是刻意的一次性旗標。

### 資產

- **60 個唯一檔名**（其中 57 個內容互異——有 3 對是同內容不同檔名），散在 8 個故事資料夾共 116 份參照（260 MB）。**無同名不同內容的衝突**，可安全依檔名攤平成單一共用池。
- 背景 15 張（含 3 張災難變體）+ CG 1 張（`cg_column_rising`，01/04/07 共用）。
- 立繪 44 張（16 角色的基底與表情差分）。
- **立繪未去背**（`hasAlpha: no`，平灰底 1024×1536）。**未對齊**（表情差分與基底有尺度／位置飄移）。
- 單張 2.2–2.6 MB。

## 設計

### 1. 專案結構

```
vn/
├── .fvmrc                    { "flutter": "3.38.5" }  ← 對齊 frontend/
├── pubspec.yaml
├── web/
├── tool/
│   └── import_pack.py        writer → assets 的匯入腳本（可重跑）
├── assets/content/pompeii-79/
│   ├── pack.json
│   ├── assets/
│   │   ├── backgrounds/      16 PNG（15 背景 + 1 CG）
│   │   ├── sprites/          44 PNG（去背 + 對齊）
│   │   └── audio/            （空）
│   └── stories/
│       ├── 01-harbour-stranger/story.json    ← 逐字複製
│       └── … 08
├── lib/
│   ├── main.dart             薄殼：ProviderScope + MaterialApp.router + go_router
│   └── src/visual_novel/     ← 這一包整包搬進 frontend/lib/features/visual_novel/
│       ├── providers.dart    公開介面（frontend 的依賴規則要求跨 feature 只能引這個）
│       ├── domain/
│       │   ├── story.dart            Story / Scene / StoryNode（sealed）/ Ending / VariableSpec
│       │   ├── cursor.dart           Cursor（節點指標 ＝ 呼叫堆疊的投影）
│       │   ├── play_state.dart       cursor / vars / readNodes / status
│       │   ├── story_player.dart     純函式執行器
│       │   └── save_data.dart
│       ├── data/
│       │   ├── story_json_parser.dart    story.json → domain
│       │   ├── pack_repository.dart      rootBundle 讀 pack.json / story.json
│       │   └── save_store.dart           SharedPreferences
│       └── presentation/
│           ├── pack/         景點包首頁（8 篇卡片）
│           ├── play/         播放頁與其分層 widget
│           ├── endings/      結局收藏
│           └── settings/
└── test/                     鏡射 lib/ 結構
```

**技術選型跟 `frontend/` 一致**：Riverpod（`Notifier` / `AsyncNotifier`）、go_router、shared_preferences。搬過去不必改寫。

**`domain/` 零 Flutter 依賴**（只 import `dart:*` 與 `package:meta`），這樣執行器可以用 `dart test` 秒跑，也讓「搬進 frontend 後 domain 層乾淨」這條架構規則在一開始就成立。

### 2. 資料模型（`domain/story.dart`）

`StoryNode` 是 sealed class，11 個子型別對應 `t`：

```dart
sealed class StoryNode {}

final class NarrationNode  extends StoryNode { final String text; final String? style; }
final class DialogueNode   extends StoryNode { final String who, text; final String? sprite; }
final class ShowNode       extends StoryNode { final String who, sprite; final String? filter; }
final class HideNode       extends StoryNode {}
final class SfxNode        extends StoryNode { final String id; }
final class BgmNode        extends StoryNode { final String? id; }        // null ＝ 停止
final class CgNode         extends StoryNode { final String id; final bool fullscreen, hideDialogue; }
final class AddNode        extends StoryNode { final Map<String, num> vars; }
final class SetNode        extends StoryNode { final Map<String, Object?> vars; }
final class IfNode         extends StoryNode { final Condition cond; final List<StoryNode> then, orElse; }
final class ChoiceNode     extends StoryNode { final List<ChoiceOption> options; }
```

```dart
final class ChoiceOption {
  final String text;
  final Condition? cond;              // 不成立 ＝ 不顯示（規範漏寫）
  final Map<String, num>? add;
  final Map<String, Object?>? set;
  final List<StoryNode> then;         // 預設空
  final String? goto;
  final List<BranchRule> branch;      // 依序求值，第一個成立者生效
}

final class Condition { final String varName; final String op; final Object? value; }
```

`Condition.evaluate(vars)`：未宣告變數取 `null`。`>=` `<=` `>` `<` 只在兩邊都是 `num` 時比較，否則為 `false`；`==` `!=` 走值相等（`null` 與 `false` 不視為相等，照 Dart 語意）。

> **為什麼不用 `freezed`／`json_serializable`**：`story.json` 的節點是 `t` 判別的異質陣列 + 巢狀遞迴，手寫 parser 比產生器好讀也好錯誤定位，且省掉 `build_runner` 這道流程。`domain` 因此也不需要任何 codegen 依賴。

### 3. 執行器（`domain/story_player.dart`）

**核心：節點指標 ＝ 呼叫堆疊的投影。** 不需要另存 stack——`Cursor` 本身就是路徑，讀檔時從場的 root 節點陣列依路徑重新解析即可。

```dart
final class CursorStep { final int index; final String? branch; }   // branch: 'then' | 'else' | 'opt<n>'
final class Cursor { final String sceneId; final List<CursorStep> path; }
```

序列化成 `Flutter製作規範` §6 的形狀：`["12", "then", "3"]`。

執行迴圈是純函式：

```dart
PlayState advance(Story story, PlayState state);          // 推進一個節點
PlayState choose(Story story, PlayState state, int i);    // 選第 i 個「可見」選項
```

`advance` 的規則：

1. 解析 cursor → 目前節點。
2. **副作用型節點**（`sfx` / `bgm` / `add` / `set` / `show` / `hide`）不停頓，套用後直接繼續往下走，直到碰到**會停頓的節點**（`n` / `d` / `cg` / `choice`）或走完。
3. `if`：求值後 push 一層（`branch: 'then'` 或 `'else'`），進入子陣列。
4. 走完一層 → pop 回上層，index + 1。
5. 走完場的 root 陣列 → 依場的 `next` 跳下一場；`isEnding` 為真 → `status: ended`，記 `endingId`。

`choose` 的規則：套用 `add` / `set` → 若有 `then` 就 push（`branch: 'opt<i>'`）進入；否則依 `branch` 規則或 `goto` 跳場；兩者皆無則 pop 回上層繼續。

**已讀鍵**：`<sceneId>#<path.join('.')>`，例 `S06#12.then.3`（規範 §5）。

**變數上下限**：`add` 後夾在宣告的 `min`／`max` 之間。未宣告的變數不夾。

### 4. 播放版面（照 `Flutter製作規範` §2）

以螢幕高 `H`、寬 `W` 為單位：

| 元件 | 規格 |
|---|---|
| 背景 | `BoxFit.cover`、`Alignment.topCenter` |
| 立繪 | 高 `0.72H`，水平置中（雙人各偏移 `0.18W`），底邊在 `0.88H` |
| 對話框 | 底部 `0.35H`，`#1C1A19` @ 0.82，上緣細微漸層 |
| 名牌 | 突出對話框上緣，左內縮 `0.06W` |
| 正文 | 內縮 `0.06W`，3 行 × 18–20 字，字級 `W / 20` |
| 選項 | `0.45H`–`0.75H`，內縮 `0.10W`（實測最多 3 項） |
| 安全區 | 上下各 `0.08H` |

**同時在台上的立繪最多 2 個**（實測：單人 223 次、雙人 6 次，無三人）。`show` 累加、`hide` 全部收起。

節點型別到畫面的對應：

- **`n`**：對話框**不顯示名牌**。`style: "graffiti"`（5 處）走不同字體 + 淡色。
- **`d`**：名牌 ＝ `who` 的 `name`。`sprite` 存在時同時切換該角色表情。**主角（`isPlayer: true`，`sprites: null`）有名牌無立繪**。
- **`show` / `hide`**：立繪進出。`filter: "memory_desaturate"` → `ColorFiltered` 去飽和。
- **`cg`**：全螢幕圖，`hideDialogue` 時關掉對話框，點擊繼續。
- **`sfx` / `bgm`**：走 `AudioPort` 介面，本輪的實作是 no-op（見 §7）。

**直式鎖定**：`vn/` 只跑直式。Web 上以 `AspectRatio` 9:16 置中呈現，兩側留黑，模擬手機。

### 5. 功能

| # | 功能 | 說明 |
|---|---|---|
| 1 | 點擊推進 | 全螢幕點擊推進一個節點 |
| 2 | **逐字顯示 + 點擊補完** | 未顯示完時點擊先補完，再點才推進 |
| 3 | **回顧 backlog** | 往回捲已讀文字，含說話者 |
| 4 | **已讀跳過** | 只跳已讀節點，碰到未讀即停 |
| 5 | **結局收藏** | 已達成顯示標題，未達成只顯示鎖頭（不劇透） |
| 6 | **設定** | 文字速度、字級 |
| 7 | 存讀檔 | 自動存檔（per story）+ 全域結局檔 |

自動播放（規範 §5.2）與音量設定不在本輪——自動播放等有音訊才有意義，音量在無聲的包裡是死的開關。

**存檔**（`shared_preferences`，照規範 §6）：

```json
{ "storyId": "pompeii_01_harbour_stranger",
  "cursor": { "sceneId": "S06", "path": ["12", "then", "3"] },
  "vars": { "affection": 2, "deal": "wait" },
  "updatedAt": "<ISO8601>" }
```

`readNodes` 與 `endingsSeen` **另存兩份全域鍵**（跨 8 篇共用），`readNodes` 是排序後的字串陣列。8 篇合計 2,296 個唯一鍵、平均長 7 字元，全部讀完約 16 KB 原始字串（含 JSON 引號與逗號約 35 KB）——`shared_preferences` 吃得下，規範 §6 提到的 bitset 壓縮先不做。

### 6. 匯入腳本（`vn/tool/import_pack.py`）

純 Python + PIL + numpy（環境已有 PIL 12.1.1 / numpy 1.26.4）。可重跑，`writer/` 更新後重跑即同步。

```
python3 vn/tool/import_pack.py [--webp] [--no-cache]
```

流程：

1. **複製劇本**：`writer/創作/龐貝/stories/<n>_<中文>/story.json` → `vn/assets/content/pompeii-79/stories/<order>-<slug>/story.json`，**逐字複製**。slug 取自 `meta.id` 去掉 `pompeii_NN_` 前綴。
2. **去重資產**：116 份參照 → 60 個檔案，依 basename 攤平成 `assets/backgrounds/` 與 `assets/sprites/`。`cg_*.png` 歸 `backgrounds/`（來源就放那裡）。**衝突偵測**：同名不同 hash 即中止並報錯。
3. **立繪去背**：平灰底 → alpha。四邊界種子的容差 flood fill（8 連通）→ 邊緣 1px 羽化。只處理 `sprites/`，背景不動。
4. **表情對齊**：同角色的差分對基底做**正規化互相關的縮放 + 平移搜尋**（縮放 0.92–1.08、平移 ±64px，先在 1/4 解析度粗搜再細修），輸出對齊後的差分。
   > 規範 §4.2 指定用「兩眼中點 + 眼距」對齊，但環境沒有臉部偵測可用。差分本來就是 image-to-image 從基底生成的，整體相關性夠高，**全域對齊在此等價且更穩**。這是對規範的刻意偏離，記在此處以免日後被當成實作疏漏。
5. **快取**：去背與對齊的產物存 `writer/創作/龐貝/美術測試/_processed/`（以來源檔 hash 命名），重跑不重算。`--no-cache` 強制重來。
6. **產 `pack.json`**：景點包 meta + 8 篇索引（`id` / `order` / `title` / `subtitle` / `estimatedMinutes` / `dir`）。
7. **驗證**：每篇 `story.json` 參照的每個背景、立繪、CG 檔案都在；不在就中止。
8. `--webp`：轉 WebP（背景 q80、立繪 q85 帶 alpha）。**預設關閉**，送審前才開。

**對照圖**：去背與對齊各輸出一張 before/after 拼接圖到 `vn/tool/_review/`，供人工驗收（風險 1、2 的處置）。

### 7. 音訊與缺件降級

`domain` 定義 `AudioPort`（`playBgm(String?)` / `playSfx(String)`），`data` 提供 `SilentAudioAdapter`（no-op）。`sfx` 與 `bgm` 節點照常執行、照常記錄，只是沒有聲音。等音訊備齊，換一個 adapter 即可，引擎不動。

`missingAssets` 由 parser 讀進來，repository 在解析資產路徑時比對：命中就回 `null`，presentation 據此不繪製／不播放，**不得丟例外**。

### 8. 導覽

```
/                      景點包首頁：龐貝 79，8 篇卡片（標題／副標／分鐘數／結局進度 n/3）
/play/:storyId         播放頁
/endings               結局收藏
/settings              設定
```

go_router，`storyId` 用 `meta.id`。

### 9. 刪除

移除整個 `story/` 目錄（Vite + React SPA、兩篇舊劇本共 30 MB、`src/editor/` 15 檔、`plugins/editor-api/`）。同步更新 `CLAUDE.md` 的 repo 結構表：拿掉 `story/` 那列，加上 `vn/`。

## 測試

### 純 Dart（`dart test`，不需模擬器）

1. **執行器**：副作用節點不停頓、`if` 兩側、巢狀 push/pop 正確回到上層、`choice` 的 `then` / `goto` / `branch` / 無出口三種路徑。
2. **條件求值**：`>=` `==` 六種運算子、未宣告變數取 `null`、型別不符時為 `false`。
3. **變數夾限**：`add` 不超過宣告的 `min`／`max`；未宣告變數不夾。
4. **Cursor 往返**：序列化 → 反序列化 → 解析回同一個節點。
5. **parser**：11 種節點型別、`option.cond`、`show.filter`、`bgm: null` 都解得出來；未知 `t` 要報明確錯誤而不是靜默忽略。

### 以 8 篇真實 `story.json` 為輸入的走訪測試

這是本專案最有價值的一組測試——內容是既成事實，引擎必須吃得下：

6. **全篇可解析**：8 篇都 parse 成功。
7. **結局可達**：窮舉所有選擇組合（40 個選擇點、每點 2–3 項，單篇上界 `3^7 = 2,187`），驗證 **24 個結局全部走得到**。
8. **分歧覆蓋**：每個 `choice` 的每個選項、每個 `if` 的兩側，至少被走過一次。
9. **無死路**：任一組合都能走到某個結局，不會卡在沒有出口的節點。
10. **變數邊界**：所有路徑上的變數不超過宣告的 `max`。
11. **資產完整**：每個參照的檔案都在 `vn/assets/` 內。
12. **文字長度**：所有 `n` / `d` 節點文字 ≤ 60 字（規範 §2 的硬規則；實測最長 57）。

### Widget test（`fvm flutter test`）

照 `flutter-widget-tests` skill 的規範（BDD 命名、fake over mock、互動優先於靜態渲染）：

13. 對話框顯示文字、名牌只在 `d` 出現。
14. 逐字顯示中點擊 → 補完；補完後點擊 → 推進。
15. 選項只顯示 `cond` 成立者；點選後套用 `add` 並走對分支。
16. `cg` 的 `hideDialogue` 真的關掉對話框。
17. 缺件降級：`sfx` / `bgm` / 缺圖不造成例外。
18. backlog 顯示已讀文字與說話者。
19. 已讀跳過碰到未讀節點即停。
20. 存檔往返：存檔後讀回，cursor 與變數一致。

**每次改動跑 `fvm flutter analyze --fatal-infos`，零問題才算完成。**

## 風險

| # | 風險 | 影響 | 處置 |
|---|---|---|---|
| 1 | **去背品質**——髮絲、灰色斗篷與灰底相近 | 立繪留灰邊或被啃掉 | 先做 1 張給 user 驗收再全跑；輸出 before/after 對照圖 |
| 2 | **表情對齊**——飄移太大時全域對齊補不回來 | 切表情時人物跳動 | 輸出對照圖；若某角色補不回來，退為「該角色只用基底」 |
| 3 | **Web 首次載圖延遲**——單張 2.5 MB PNG 走 HTTP | 進場卡頓 | `precacheImage` 預載下一節點的背景與立繪；搬手機端後消失 |
| 4 | **整包無聲** | 災難敘事失去「時鐘」（規範 §5.4 說音效優先於美術精細度） | 本輪不解決，`AudioPort` 留介面 |
| 5 | **搬進 `frontend/` 的架構債** | 屆時要大改 | `providers.dart` 當唯一公開介面、`domain/` 零 Flutter 依賴，這兩條從第一天守住 |
| 6 | **`writer/` 不進版控** | 內容來源只在本機 Obsidian vault | 匯入後的 `vn/assets/content/` 進版控，等於一份快照 |

## 未決（不阻擋本輪）

- 音訊：BGM 15 首 / SFX 26 個。
- 立繪去背後是否要統一後製（色調、邊緣）——先看去背結果再決定。
- 搬進 `frontend/` 的時機與方式（新 route？獨立 tab？），等 Web 驗證完再談。
- 260 MB PNG 的最終壓縮策略（`--webp` 已預留）。

## 相關文件

- `writer/創作/龐貝/產品規格書.md` — 形式、SKU、變現結構
- `writer/製作規範/Flutter製作規範.md` — 版面數值、`story.json` schema、必備功能、測試清單
- `writer/創作/龐貝/美術風格聖經.md` — 直式版面與資產規格
- `writer/創作/龐貝/龐貝史實紅線.md` — 史實邊界
- `writer/創作/龐貝/進度與交接.md` — 內容與美術的完成狀態
