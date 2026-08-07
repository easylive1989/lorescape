"""executor.publish_row 發布行為測試。"""
from __future__ import annotations

import dataclasses
from unittest.mock import MagicMock, patch

from lorescape_publisher import executor
from lorescape_publisher.instagram import ReelUploadGenericError
from tests._fakes import FakeSupabase


def _client():
    client = MagicMock()
    table = client.table.return_value
    table.upsert.return_value.execute.return_value = MagicMock(data=None)
    return client, table


def _carousel_row(**overrides):
    base = dict(
        id="r1", publish_date="2026-07-09", media_type="carousel",
        status="scheduled", review_decision="approved",
        slide_urls=["https://x/1.jpg", "https://x/2.jpg"],
        caption="cap", ig_post_id=None,
    )
    base.update(overrides)
    return base


@patch("lorescape_publisher.executor.instagram.publish_carousel",
       return_value="ig-123")
def test_publish_carousel_row_publishes_and_records(mock_pub, fake_config):
    client, table = _client()

    ok = executor.publish_carousel_row(fake_config, client, _carousel_row())

    assert ok is True
    mock_pub.assert_called_once()
    kwargs = mock_pub.call_args.kwargs
    assert kwargs["image_urls"] == ["https://x/1.jpg", "https://x/2.jpg"]
    assert kwargs["caption"] == "cap"
    payload, = table.upsert.call_args.args
    assert payload["status"] == "published"
    assert payload["ig_post_id"] == "ig-123"


@patch("lorescape_publisher.executor.instagram.publish_carousel",
       side_effect=RuntimeError("boom"))
def test_publish_carousel_row_records_failure(mock_pub, fake_config):
    client, table = _client()

    ok = executor.publish_carousel_row(fake_config, client, _carousel_row())

    assert ok is False
    payload, = table.upsert.call_args.args
    assert payload["status"] == "failed"
    assert "boom" in payload["error"]


@patch("lorescape_publisher.executor.instagram.publish_carousel")
def test_publish_row_skips_already_published(mock_pub, fake_config):
    sb = FakeSupabase([
        _carousel_row(status="published", ig_post_id="ig-old"),
    ])

    ok = executor.publish_row(
        fake_config, sb, _carousel_row(status="published",
                                        ig_post_id="ig-old"),
    )

    assert ok is True
    mock_pub.assert_not_called()


@patch("lorescape_publisher.executor.instagram.publish_carousel")
def test_publish_row_reread_guard_blocks_stale_snapshot(mock_pub, fake_config):
    """兩個並發發布：第二個讀到的 in-memory row 是「尚未發布」的舊快照，
    但 DB 裡其實已經被第一個 request 標記成 published 了。鎖內重讀 DB
    最新狀態必須擋下這次重複發布。"""
    sb = FakeSupabase([
        _carousel_row(status="published", ig_post_id="ig-old"),
    ])
    stale_snapshot = _carousel_row(status="scheduled", ig_post_id=None)

    ok = executor.publish_row(fake_config, sb, stale_snapshot)

    assert ok is True
    mock_pub.assert_not_called()


@patch("lorescape_publisher.executor.instagram.publish_carousel",
       return_value="ig-new")
def test_publish_row_force_republishes_terminal_row(mock_pub, fake_config):
    row = _carousel_row(status="failed", ig_post_id="ig-old")
    sb = FakeSupabase([dict(row)])

    ok = executor.publish_row(fake_config, sb, row, force=True)

    assert ok is True
    mock_pub.assert_called_once()
    assert sb.rows[0]["status"] == "published"
    assert sb.rows[0]["ig_post_id"] == "ig-new"


@patch("lorescape_publisher.executor.instagram.publish_carousel",
       return_value="ig-123")
def test_publish_row_happy_path_publishes_fresh_row(mock_pub, fake_config):
    row = _carousel_row(status="scheduled", ig_post_id=None)
    sb = FakeSupabase([dict(row)])

    ok = executor.publish_row(fake_config, sb, row)

    assert ok is True
    mock_pub.assert_called_once()
    assert sb.rows[0]["status"] == "published"
    assert sb.rows[0]["ig_post_id"] == "ig-123"


@patch("lorescape_publisher.executor.instagram.publish_carousel")
def test_publish_carousel_row_noops_when_ig_disabled(mock_pub):
    from lorescape_publisher.config import Config
    config = Config(
        supabase_url="u", supabase_service_role_key="k", gemini_api_key="g",
        discord_webhook_url=None, discord_bot_token=None,
        discord_review_channel_id=None, discord_approver_ids=(),
        ig_user_id=None, meta_page_access_token=None,
        brand_handle_ig="", cta_text="",
    )
    client, table = _client()

    ok = executor.publish_carousel_row(config, client, _carousel_row())

    assert ok is False
    mock_pub.assert_not_called()


def _reel_row(**overrides):
    base = dict(
        id="r2", publish_date="2026-07-09", media_type="reel",
        status="scheduled", review_decision="approved", ig_post_id=None,
    )
    base.update(overrides)
    return base


@patch("lorescape_publisher.executor.reel_publisher.build_reel_caption",
       side_effect=RuntimeError("bad caption"))
def test_publish_reel_row_records_failure_when_caption_build_raises(
    mock_caption, fake_config, tmp_path,
):
    client, table = _client()
    (tmp_path / "2026-07-09").mkdir()
    (tmp_path / "2026-07-09" / "final.mp4").write_bytes(b"fake video")
    config = dataclasses.replace(fake_config, daily_video_dir=str(tmp_path))

    ok = executor.publish_reel_row(config, client, _reel_row())

    assert ok is False
    mock_caption.assert_called_once()
    payload, = table.upsert.call_args.args
    assert payload["status"] == "failed"
    assert "bad caption" in payload["error"]


@patch("lorescape_publisher.executor.instagram.publish_reel",
       return_value="ig-reel-1")
@patch("lorescape_publisher.executor.reel_cover.build_cover_url",
       return_value="https://x/cover.jpg")
@patch("lorescape_publisher.executor.reel_publisher.build_reel_caption",
       return_value="a caption")
def test_publish_reel_row_publishes_and_records(
    mock_caption, mock_cover, mock_pub, fake_config, tmp_path,
):
    client, table = _client()
    (tmp_path / "2026-07-09").mkdir()
    (tmp_path / "2026-07-09" / "final.mp4").write_bytes(b"fake video")
    config = dataclasses.replace(fake_config, daily_video_dir=str(tmp_path))

    ok = executor.publish_reel_row(config, client, _reel_row())

    assert ok is True
    mock_pub.assert_called_once()
    payload, = table.upsert.call_args.args
    assert payload["status"] == "published"
    assert payload["ig_post_id"] == "ig-reel-1"


def _reel_video_dir(fake_config, tmp_path):
    (tmp_path / "2026-07-09").mkdir()
    (tmp_path / "2026-07-09" / "final.mp4").write_bytes(b"fake video")
    return dataclasses.replace(fake_config, daily_video_dir=str(tmp_path))


@patch("lorescape_publisher.reel_publisher.instagram.publish_reel_from_url",
       return_value="ig-reel-url-1")
@patch("lorescape_publisher.reel_publisher.reel_video_storage")
@patch("lorescape_publisher.executor.instagram.publish_reel",
       side_effect=ReelUploadGenericError(
           "Reel upload failed with HTTP 400 for container 1: "
           '{"debug_info":{"type":"ProcessingFailedError"}}'))
@patch("lorescape_publisher.executor.reel_cover.build_cover_url",
       return_value="https://x/cover.jpg")
@patch("lorescape_publisher.executor.reel_publisher.build_reel_caption",
       return_value="a caption")
def test_publish_reel_row_falls_back_to_video_url_on_generic_rupload_failure(
    mock_caption, mock_cover, mock_pub, mock_storage, mock_from_url,
    fake_config, tmp_path,
):
    """F11 的 video_url 退路必須在**正式路徑**（executor）上生效。

    2026-07-27 / 08-02 / 08-07 三次 reel 發布失敗都是因為 executor 直接
    呼叫 instagram.publish_reel，繞過了 publish_reel_with_fallback。
    """
    client, table = _client()
    config = _reel_video_dir(fake_config, tmp_path)
    mock_storage.upload_reel_video.return_value = (
        "https://x/reel-videos/2026-07-09/final.mp4"
    )

    ok = executor.publish_reel_row(config, client, _reel_row())

    assert ok is True
    assert mock_storage.upload_reel_video.call_args.kwargs["path"] == (
        "2026-07-09/final.mp4"
    )
    from_url_kwargs = mock_from_url.call_args.kwargs
    assert from_url_kwargs["video_url"] == (
        "https://x/reel-videos/2026-07-09/final.mp4"
    )
    assert from_url_kwargs["caption"] == "a caption"
    assert from_url_kwargs["cover_url"] == "https://x/cover.jpg"
    mock_storage.delete_reel_video.assert_called_once()
    payload, = table.upsert.call_args.args
    assert payload["status"] == "published"
    assert payload["ig_post_id"] == "ig-reel-url-1"


@patch("lorescape_publisher.reel_publisher.instagram.publish_reel_from_url")
@patch("lorescape_publisher.reel_publisher.reel_video_storage")
@patch("lorescape_publisher.executor.instagram.publish_reel",
       side_effect=RuntimeError("failed to transcode"))
@patch("lorescape_publisher.executor.reel_cover.build_cover_url",
       return_value="https://x/cover.jpg")
@patch("lorescape_publisher.executor.reel_publisher.build_reel_caption",
       return_value="a caption")
def test_publish_reel_row_does_not_fall_back_on_content_failure(
    mock_caption, mock_cover, mock_pub, mock_storage, mock_from_url,
    fake_config, tmp_path,
):
    """轉碼類錯誤代表影片本身有問題，video_url 也救不了 —— 照舊 failed。"""
    client, table = _client()
    config = _reel_video_dir(fake_config, tmp_path)

    ok = executor.publish_reel_row(config, client, _reel_row())

    assert ok is False
    mock_from_url.assert_not_called()
    mock_storage.upload_reel_video.assert_not_called()
    payload, = table.upsert.call_args.args
    assert payload["status"] == "failed"
    assert "failed to transcode" in payload["error"]
