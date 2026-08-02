# 排程自動發布失敗時通知 Discord 審核頻道 — Design

- **日期**：2026-08-03
- **背景事故**：ISSUE-002（2026-08-02 巨石陣 reel 自動發布失敗，無任何通知，隔天才發現）

## 問題

publisher 的發布有兩條路徑：

1. **🚀 立即發布按鈕**（`interactions.publish_now` / `republish`）：失敗時
   bot 會回 ephemeral「發布失敗，見 log」——有通知。
2. **排程自動發布**（`bot_flows/scheduler.tick` → `executor.publish_row`）：
   `tick()` 忽略 `publish_row` 的回傳值，失敗只寫 `social_posts`
   （status=`failed`）與容器 log，不發任何 Discord 訊息。row 一變
   `failed` 就離開 `list_scheduled_due`（只查 status=`scheduled`）的
   範圍，之後不會再被撿起——失敗完全無聲。

（舊 `reel_publisher.py` 路徑有 `DISCORD_WEBHOOK_URL` 通知，但現行 bot
架構不走那裡。）

## 目標

排程自動發布失敗時，在**審核頻道**收到一則 bot 訊息，含失敗的
media_type、DB 記錄的錯誤內容、以及「可按 🚀 重試」的提示。

## 設計

只改 `publisher/src/lorescape_publisher/bot_flows/scheduler.py` 的
`tick()`：

- 接住 `executor.publish_row(...)` 的回傳值。
- 回傳 `False` 時，用 `post_log.get_post` 重讀該列：
  - 若 `status == "failed"`：呼叫既有注入的
    `notify(publish_date, message)`（與「排程到點但尚未核准」提醒同一
    機制，訊息落在審核頻道），內容形如：

    ```
    [2026-08-02] 自動發布失敗（reel）：Reel upload failed with HTTP 400 …
    可按原審核訊息的 🚀 重試補發。
    ```

  - 若仍是 `scheduled`（例如暫時性設定問題導致 early-return、未記
    failed）：不通知——下一分鐘 tick 會再試，避免每分鐘洗版。

### 去重

不需新欄位：失敗列已離開 `scheduled` 狀態，不會再進
`list_scheduled_due`，通知天然只發一次。

### 截斷

`social_posts.error` 在 executor 端已截 1000 字；通知訊息再截到 600
字，加上前綴遠低於 Discord 2000 字上限。

### 不動的部分

- `executor.py`（職責不變：發布＋記錄）
- 按鈕路徑的 ephemeral 回覆
- 舊 `reel_publisher.py` 與 `discord_notify` webhook 機制
- carousel 與 reel 走同一段 generic 處理，同時受惠

## 測試

`scheduler.tick` 為純函式（不 import discord），於現有 scheduler 測試
新增案例：

1. `publish_row` 回 `False` 且重讀 status=`failed` → `notify` 被呼叫，
   訊息含 media_type 與 error 內容。
2. `publish_row` 回 `True` → 不呼叫 `notify`。
3. `publish_row` 回 `False` 但重讀仍為 `scheduled` → 不呼叫 `notify`。
