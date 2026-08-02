"""bot.scheduler.tick 排程迴圈測試。"""
from __future__ import annotations

import dataclasses
from datetime import datetime, timezone
from unittest.mock import patch

from lorescape_publisher.bot_flows import scheduler
from tests._fakes import FakeSupabase

NOW = datetime(2026, 7, 9, 13, 0, tzinfo=timezone.utc)
PAST = "2026-07-09T12:00:00+00:00"
FUTURE = "2026-07-09T14:00:00+00:00"


def _row(**o):
    base = dict(
        publish_date="2026-07-09", media_type="carousel", status="scheduled",
        review_decision="approved", scheduled_at=PAST,
        overdue_notified_at=None, ig_post_id=None,
    )
    base.update(o)
    return base


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row",
       return_value=True)
def test_due_and_approved_publishes(mock_pub, fake_config):
    sb = FakeSupabase([_row()])
    notes = []
    scheduler.tick(fake_config, sb, now=NOW, notify=lambda d, m: notes.append((d, m)))
    mock_pub.assert_called_once()
    assert notes == []


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row")
def test_due_but_unapproved_notifies_once(mock_pub, fake_config):
    sb = FakeSupabase([_row(review_decision=None)])
    notes = []
    scheduler.tick(fake_config, sb, now=NOW, notify=lambda d, m: notes.append((d, m)))
    scheduler.tick(fake_config, sb, now=NOW, notify=lambda d, m: notes.append((d, m)))
    mock_pub.assert_not_called()
    assert len(notes) == 1  # 只提醒一次
    assert sb.rows[0]["overdue_notified_at"] is not None


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row")
def test_not_due_is_ignored(mock_pub, fake_config):
    sb = FakeSupabase([_row(scheduled_at=FUTURE)])
    scheduler.tick(fake_config, sb, now=NOW, notify=lambda d, m: None)
    mock_pub.assert_not_called()


@patch("lorescape_publisher.bot_flows.scheduler.executor.publish_row")
def test_publish_disabled_noops(mock_pub, fake_config):
    config = dataclasses.replace(fake_config, daily_story_publish_enabled=False)
    sb = FakeSupabase([_row()])
    scheduler.tick(config, sb, now=NOW, notify=lambda d, m: None)
    mock_pub.assert_not_called()


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
