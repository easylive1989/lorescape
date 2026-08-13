# story 引擎：choice flag 與條件段落／選項

**日期**：2026-08-13
**範圍**：`story/`（Vite + React SPA，含播放頁與 `/editor` 工作台）與 `story/public/content/pompeii-bakery/`

## 問題

引擎目前沒有任何狀態：`PlayState` 只有 `{ nodeId, paragraphIndex, status }`，玩家的選擇除了「跳到哪個節點」之外不留下痕跡。分支一旦匯流，先前選過什麼就再也讀不到。

《八十一條麵包》因此有兩個具體損失：

1. **結局無法依先前選擇分岔。** 第一個選擇（封爐／現在就走）決定了那八十一條麵包會不會被封在爐裡留到兩千年後。這件事本來該由博物館結局講出來——「其中一條頂上有一個小小的凹痕」——但結局是共用節點，只好對指印保持沉默，讓讀者自己從分支的伏筆補。原本最強的一句「指印是她的」因此被拿掉。
2. **選項數不同的節點必須整份複製。** 封爐分支少一條逃生路（港口被塌下的門廊封死），所以 `n5b2` 只有兩個選項、`n5a2` 有三個。因為選項清單綁在節點上，連帶把前面的 `n5a`／`n5b` 也複製成兩份。

要做的是讓選項可以留下 flag，並讓段落與選項能依 flag 顯示或隱藏。

## 非目標

- **背景不依 flag 切換。** 節點背景維持單一值。要換背景就換節點，這是既有的、夠用的做法。
- **不合併 `n5a`／`n5b`。** 這兩份散文已經刻意寫得不同（封爐分支是「晚一刻鐘的街」：人少了、地上全是別人扔掉的東西）。合併會失去這個差異。條件選項的價值在未來的劇本，不在回頭改這一篇。
- **不做數值、不做計數器。** flag 只有「有」與「沒有」兩種狀態。

## 設計

### 1. 資料模型（`src/engine/schema.ts`）

```ts
// flag 名稱：kebab-case
const FLAG = /^[a-z][a-z0-9-]*$/
// 條件：flag 或 !flag
const CONDITION = /^!?[a-z][a-z0-9-]*$/

export const paragraphSchema = z.object({
  text: z.string().min(1),
  speaker: z.string().optional(),
  when: z.string().regex(CONDITION).optional(),
})

export const choiceSchema = z.object({
  text: z.string().min(1),
  to: z.string().min(1),
  set: z.array(z.string().regex(FLAG)).optional(),
  when: z.string().regex(CONDITION).optional(),
})
```

條件用**單一 `when` 欄位**、以 `!` 前綴表示否定，而不是 `when` / `whenNot` 兩個欄位：概念只有一個，schema 也少一個要交叉檢查的組合（兩個欄位同時給值時該怎麼辦，這個問題直接不存在）。regex 保證 `!` 只能出現在開頭。

`nodeSchema`、`castMemberSchema`、`characterSchema` 都不動。

### 2. 守門規則（`validateScript` 新增四條）

| # | 規則 | 錯誤訊息 |
|---|---|---|
| 1 | `set` 的每個 flag 名稱合法 | （由 zod regex 擋下） |
| 2 | `when` 參照的 flag 必須有某個 choice `set` 過它 | `節點 <id> 參照從未設定過的 flag：<flag>` |
| 3 | 每個節點至少一段**無條件**段落 | `節點 <id>：至少要有一段沒有 when 的段落` |
| 4 | 有 `choices` 的節點，**無條件**選項至少 2 個 | `節點 <id>：沒有 when 的選項至少要有兩個` |

規則 2 擋的是打錯字——`when: "seald"` 這種錯誤在執行期只會表現成「那段永遠不出現」，靜態擋掉才找得到。

規則 3、4 是刻意把動態問題轉成靜態檢查：有了它們，執行期不可能遇到「整個節點被條件清空」或「選單一個選項都沒有」，`advance` 與 `SceneView` 因此不需要寫防禦分支。

規則 4 檢查的是無條件選項數，不是總數——因為 flag 的組合在靜態時不可知，只有無條件選項才保證任何情況下都在。

### 3. 執行期（`src/engine/player.ts`）

```ts
export type PlayState = {
  nodeId: string
  paragraphIndex: number
  status: PlayStatus
  flags: string[]
}
```

用 `string[]` 而不是 `Set<string>`：`PlayState` 會整個 `JSON.stringify` 進 localStorage，Set 不能序列化。

新增兩個純函式，可見性的判斷只發生在這裡：

```ts
export function matches(condition: string | undefined, flags: string[]): boolean
export function visibleParagraphs(node: ScriptNode, flags: string[]): Paragraph[]
export function visibleChoices(node: ScriptNode, flags: string[]): Choice[]
```

- `initState` 回傳 `flags: []`
- `advance` 改用 `visibleParagraphs(node, state.flags).length` 判斷是否已到最後一段
- `choose(script, state, index)` 的 `index` 改成**可見選項**的索引；選中後把該選項的 `set` 併進 `flags`：依 `set` 的順序附加到陣列尾端，已存在的跳過。順序穩定，存檔比對才不會因為排列不同而失效

`flags` 只增不減——沒有 unset。故事是單向前進的，沒有回頭的需求。

### 4. 畫面（`SceneView` / `ChoiceList`）

- `SceneView` 取段落改用 `visibleParagraphs(node, state.flags)`，越界時退回最後一段的既有防禦保留（存檔可能來自改版前的劇本）
- `ChoiceList` 收 `visibleChoices(node, state.flags)`
- `PlayPage` 的 `choice_made` 追蹤事件，`index` 送的是可見索引、`text` 照舊送選項文字。可見索引與 JSON 裡的位置可能不同，追蹤看的是玩家實際點了第幾個，這是對的

### 5. 舊存檔相容（`src/data/progress.ts`）

`isPlayState` 對 `flags` 不做檢查（缺欄位或型別不對都不算存檔損壞），其餘欄位維持嚴格。正規化在 `loadProgress` 做：回傳前把 `flags` 補成 `[]`，除非它是一個字串陣列。呼叫端因此永遠拿得到合法的 `flags`。

代價：改版前存下的進度玩到結局會走 `!sealed` 那一支。那份存檔本來就不含這個資訊，無法還原，接受。

### 6. 工作台（`src/editor/panels/NodePanel.tsx`）

- **選項列**新增兩個欄位：
  - 「設定 flag」：文字輸入，逗號分隔，存成 `set: string[]`（空字串則移除該欄位）
  - 「顯示條件」：下拉，選項為「無條件」＋劇本內所有被 `set` 過的 flag 的正反兩版（`sealed` / `!sealed`）
- **段落列**新增「顯示條件」下拉，同上
- **舞台預覽**新增一排 flag 開關，切換目前預覽的 flag 狀態

flag 開關要一起做。沒有它，編輯條件段落等於盲改——中欄預覽永遠只顯示其中一種狀態，另一種要靠想像。開關狀態是編輯器的本機 UI state，不寫進 `script.json`。

## 測試

| 檔案 | 新增測試 |
|---|---|
| `engine/schema.test.ts` | 四條守門規則各一；`when` 格式非法（`!!x`、`Sealed`、空字串） |
| `engine/player.test.ts` | `matches` 的正／反／無條件；`visibleParagraphs`／`visibleChoices` 過濾；`advance` 依可見段落數收尾；`choose` 的可見索引對應正確目標；`choose` 累積 flag 且去重 |
| `data/progress.test.ts` | 舊存檔（無 `flags`）載入後補 `[]`；`flags` 非陣列時同樣補 `[]` |
| `components/SceneView.test.tsx` | 條件段落依 flag 顯示／隱藏 |
| `components/ChoiceList.test.tsx` | 條件選項依 flag 出現／消失 |
| `editor/panels/NodePanel.test.tsx` | 編輯 `set`、編輯段落與選項的 `when`、預覽 flag 開關切換 |

## 套用到《八十一條麵包》

1. `n3d` 的「把爐封好再走」選項加 `set: ["sealed"]`
2. `n9b3`（留下來的人）最後兩段改成條件段落，把指印還回去：
   - `when: "sealed"`：「……其中一條的頂上有一個小小的凹痕。麵包比你留得久。名字是別人的。指印是她的。」
   - `when: "!sealed"`：「……每一條都一樣。麵包比你留得久，名字是別人的，而那個指印沒有留下來。」
3. `n9a2`（活下來的人）同樣加一組條件段落——這條線目前完全沒提到麵包，補一句讓兩個結局都認得這個選擇
4. `n4a2`、`n4b2` 的 flash-forward 各收掉一句，把「兩千年後會怎樣」讓給結局講，避免同一件事講兩次

改完後 `n5a`／`n5b`、`n5a2`／`n5b2` 維持原樣。
