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
