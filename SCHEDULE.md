# Lorescape Scheduler 行程表

每天、每週（週一）、每月（1 號）的例行工作。使用者開工時由
`/lorescape-scheduler` skill 讀取本表、查證完成度後依序執行。格式勿改：
三個 `## ` 區段、各一張「時間｜工作｜指令 / skill」三欄表。
（2026-08-10 起 dashboard 只剩產品數據單頁，不再解析本表。）

## 每日

| 時間 | 工作 | 指令 / skill |
|---|---|---|
| 09:00 | 產生當日每日故事 → Discord 審核 → 發布 | `/lorescape-manual-daily-story` |
| 發布後 | wander 圖組（發布流程 Step 8b 自動接）→ 審核 → 發 IG | `/lorescape-wander-carousel` |
| 發布後 | 產當日 reel 影片 → 發 IG Reels | `/lorescape-daily-reel` → `/publish-reel` |
| 09:30 | 撈前一日產品數據進 `data/metrics/*.csv` | `/lorescape-metrics` |

## 每週（週一）

| 時間 | 工作 | 指令 / skill |
|---|---|---|
| 10:00 | 週報：分析最近 7 天數據 vs 前週 | `/marketing-weekly-audit` |
| 10:30 | 排下週每日故事景點 calendar | `/lorescape-reels-planner` |
| 11:00 | 週報行動清單寫進 `BACKLOG.md`；順檢「待部署」段有無卡住項目 | 手動 |

## 每月（1 號）

| 時間 | 工作 | 指令 / skill |
|---|---|---|
| 10:00 | 月報：最近 30 天數據 vs 前月 | `/marketing-monthly-audit` |
| 10:30 | 月報可執行事項寫進 `BACKLOG.md` | 手動 |
| 11:00 | 技術 SEO 定期稽核 lorescape.app | `/marketing-seo-audit` |

註記：reels calendar 期末檢核跟「期別結束日」走（如 8/3），由
`/lorescape-reels-planner` 觸發，不綁月初。
