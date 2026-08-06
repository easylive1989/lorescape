# 排程自動發布失敗通知 Discord 審核頻道 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 排程自動發布（scheduler.tick）失敗時，透過既有注入的 `notify()` 在 Discord 審核頻道發一則含錯誤內容的通知。

**Architecture:** 只改 `bot_flows/scheduler.py` 的 `tick()`：接住 `executor.publish_row` 回傳值，失敗時用 `post_log.get_post` 重讀該列，確認 `status == "failed"` 才通知（仍為 `scheduled` 表示暫時性問題、下一輪會重試，不通知避免洗版）。去重靠既有狀態機：失敗列離開 `scheduled` 後不會再進 `list_scheduled_due`。

**Tech Stack:** Python（uv 管理）、pytest、`tests/_fakes.py` 的 `FakeSupabase`。

**Spec:** `docs/superpowers/specs/2026-08-03-scheduler-publish-failure-notify-design.md`

## Global Constraints

- 不改 `executor.py`、按鈕路徑、`reel_publisher.py`、webhook 機制。
- 通知錯誤內容截斷至 600 字（DB 端已截 1000 字）。
- 所有指令在 `publisher/` 下用 `uv run` 執行。
- Commit message 用繁體中文（技術名詞除外）。

---

### Task 1: scheduler.tick 發布失敗通知

**Files:**
- Modify: `publisher/src/lorescape_publisher/bot_flows/scheduler.py`
- Test: `publisher/tests/test_bot_scheduler.py`

**Interfaces:**
- Consumes: `executor.publish_row(config, supabase, row) -> bool`（已存在）、`post_log.get_post(supabase, publish_date, media_type) -> dict | None`（已存在）、注入的 `notify(publish_date: str, message: str)`（已存在，bot 端會自動加 `[<date>] ` 前綴並送到審核頻道）。
- Produces: 無新公開介面；`tick()` 簽名不變。

- [ ] **Step 1: 寫失敗測試**

在 `publisher/tests/test_bot_scheduler.py` 檔尾新增三個測試：

```python
@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row")
def test_publish_failure_notifies_with_error(mock_pub, fake_config):
    sb = FakeSupabase([_row(media_type="reel")])

    def fail(config, supabase, row):
        # 模擬 executor：記錄 failed + error 後回 False
        sb.rows[0].update(
            status="failed",
            error="Reel upload failed with HTTP 400 ProcessingFailedError",
        )
        return False

    mock_pub.side_effect = fail
    notes = []
    scheduler.tick(fake_config, sb, now=NOW,
                   notify=lambda d, m: notes.append((d, m)))
    assert len(notes) == 1
    date, message = notes[0]
    assert date == "2026-07-09"
    assert "reel" in message
    assert "Reel upload failed with HTTP 400 ProcessingFailedError" in message
    assert "🚀" in message
    # 失敗列已離開 scheduled，第二輪不重複通知
    scheduler.tick(fake_config, sb, now=NOW,
                   notify=lambda d, m: notes.append((d, m)))
    assert len(notes) == 1


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row",
       return_value=True)
def test_publish_success_does_not_notify(mock_pub, fake_config):
    sb = FakeSupabase([_row()])
    notes = []
    scheduler.tick(fake_config, sb, now=NOW,
                   notify=lambda d, m: notes.append((d, m)))
    assert notes == []


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row",
       return_value=False)
def test_transient_false_without_failed_status_does_not_notify(
    mock_pub, fake_config
):
    # publish_row 回 False 但列仍是 scheduled（例如設定暫缺 early-return）：
    # 下一輪會重試，不該通知
    sb = FakeSupabase([_row()])
    notes = []
    scheduler.tick(fake_config, sb, now=NOW,
                   notify=lambda d, m: notes.append((d, m)))
    assert notes == []
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd publisher && uv run pytest tests/test_bot_scheduler.py -v`
Expected: 新增的 `test_publish_failure_notifies_with_error` FAIL（notes 為空，因 tick 尚未通知）；其餘兩個新測試此時會 PASS（現況本來就不通知），屬預期。

- [ ] **Step 3: 實作 tick 的失敗通知**

修改 `publisher/src/lorescape_publisher/bot_flows/scheduler.py`：

```python
"""排程迴圈：發布到點且已核准的 social_posts row。

由 publisher_bot 每分鐘呼叫一次 tick()。到點但尚未核准的 row 不發，
只透過注入的 notify 提醒一次（overdue_notified_at 去重）；發布失敗
（executor 已記 status=failed）也透過 notify 通知一次——失敗列離開
scheduled 後不會再進 list_scheduled_due，天然去重。
"""
from __future__ import annotations

import logging
from datetime import datetime
from typing import Callable

from lorescape_publisher.config import Config
from lorescape_publisher import executor, post_log

logger = logging.getLogger(__name__)

_ERROR_SNIPPET_LIMIT = 600


def tick(
    config: Config,
    supabase,
    *,
    now: datetime,
    notify: Callable[[str, str], None],
) -> None:
    """處理所有 scheduled 且到點的 row。"""
    if not config.daily_story_publish_enabled:
        return
    due_rows = post_log.list_scheduled_due(supabase, now.isoformat())
    for row in due_rows:
        if row.get("review_decision") == "approved":
            ok = executor.publish_row(config, supabase, row)
            if not ok:
                _notify_publish_failure(supabase, row, notify)
        elif row.get("review_decision") == "rejected":
            continue  # 保險：reject 已切終態，理論上不會出現在 due
        else:
            if not row.get("overdue_notified_at"):
                notify(
                    row["publish_date"],
                    f"排程時間到但尚未核准（{row['media_type']}）——"
                    f"請在 Discord 按 ✅ 或 🚀 立即發布。",
                )
                post_log.mark_overdue_notified(
                    supabase, publish_date=row["publish_date"],
                    media_type=row["media_type"],
                )


def _notify_publish_failure(
    supabase, row: dict, notify: Callable[[str, str], None]
) -> None:
    """發布失敗且 executor 已記 failed 時通知；仍為 scheduled 則留待下輪重試。"""
    fresh = post_log.get_post(supabase, row["publish_date"], row["media_type"])
    if fresh is None or fresh.get("status") != "failed":
        return
    error = (fresh.get("error") or "unknown")[:_ERROR_SNIPPET_LIMIT]
    notify(
        row["publish_date"],
        f"自動發布失敗（{row['media_type']}）：{error}\n"
        f"可按原審核訊息的 🚀 重試補發。",
    )
```

（與現行檔案相比：新增 `_ERROR_SNIPPET_LIMIT`、`_notify_publish_failure`、`ok = ...` / `if not ok` 兩行，及 docstring 補充；其餘不動。）

- [ ] **Step 4: 執行測試確認通過**

Run: `cd publisher && uv run pytest tests/test_bot_scheduler.py -v`
Expected: 全部 PASS（含原有 4 個測試）。

- [ ] **Step 5: 跑整個 publisher 測試套件**

Run: `cd publisher && uv run pytest`
Expected: 全部 PASS。

- [ ] **Step 6: Commit**

```bash
git add publisher/src/lorescape_publisher/bot_flows/scheduler.py publisher/tests/test_bot_scheduler.py
git commit -m "feat(publisher): 排程自動發布失敗時通知 Discord 審核頻道"
```
