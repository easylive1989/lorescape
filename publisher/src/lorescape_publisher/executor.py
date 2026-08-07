"""從 social_posts row 狀態發布到 Instagram（carousel / reel）。

排程迴圈與按鈕的「立即發布 / 補發」都走這裡。發布決策已由上游（bot
互動 / 排程迴圈）依 row 的 review_decision + scheduled_at 決定；executor
只負責「把這一列發出去並記錄結果」，並自帶重複發布守衛。
"""
from __future__ import annotations

import logging
import threading
from pathlib import Path

from lorescape_publisher.config import Config
from lorescape_publisher import (
    instagram,
    post_log,
    reel_cover,
    reel_publisher,
)

logger = logging.getLogger(__name__)

VIDEO_FILENAME = "final.mp4"

# 序列化發布：避免兩個 `asyncio.to_thread` worker thread（例如快速連點
# 兩下「立即發布」，或排程迴圈跟互動同時觸發）都在守衛檢查通過後才有
# 一個真的寫入 `published`，導致重複發布到 IG。
_PUBLISH_LOCK = threading.Lock()


def publish_row(
    config: Config, supabase, row: dict, *, force: bool = False
) -> bool:
    """依 media_type 分派發布；已發布過則直接回 True。

    `force=False`（預設，含排程迴圈與立即發布）：進鎖後會重讀 DB 最新的
    row 狀態；若已被別的執行緒發布過，直接回 True 不重發——這是關掉
    race 的關鍵，因為傳入的 `row` 可能是併發呼叫之間的過期記憶體快照。

    `force=True`（僅 `interactions.republish` 使用）：略過重讀守衛，直接
    用呼叫端傳入的 row（其 status/ig_post_id 已被刻意重置），藉此明確
    覆寫終態重新發布。
    """
    if not force and (
        row.get("status") == "published" or row.get("ig_post_id")
    ):
        logger.info(
            "Row %s already published (ig=%s); skipping",
            row.get("id"), row.get("ig_post_id"),
        )
        return True

    with _PUBLISH_LOCK:
        if not force:
            fresh = post_log.get_post(
                supabase, row["publish_date"], row["media_type"]
            )
            if fresh is not None:
                if fresh.get("status") == "published" or fresh.get(
                    "ig_post_id"
                ):
                    logger.info(
                        "Row %s already published by another publisher "
                        "(ig=%s); skipping",
                        fresh.get("id"), fresh.get("ig_post_id"),
                    )
                    return True
                row = fresh

        media_type = row.get("media_type")
        if media_type == "carousel":
            return publish_carousel_row(config, supabase, row)
        if media_type == "reel":
            return publish_reel_row(config, supabase, row)
        logger.warning(
            "Unknown media_type %r on row %s", media_type, row.get("id")
        )
        return False


def publish_carousel_row(config: Config, supabase, row: dict) -> bool:
    """發布 pre-rendered carousel（slide_urls + caption）。"""
    date_str = row["publish_date"]
    slide_urls = list(row.get("slide_urls") or ())
    if not config.instagram_enabled:
        logger.warning("Instagram not configured; skip carousel %s", date_str)
        return False
    if not slide_urls:
        logger.warning("Carousel %s has no slide_urls; cannot publish",
                       date_str)
        _record_failed(supabase, date_str, "carousel", "no_slide_urls")
        return False
    try:
        ig_post_id = instagram.publish_carousel(
            ig_user_id=config.ig_user_id,  # type: ignore[arg-type]
            access_token=config.meta_page_access_token,  # type: ignore[arg-type]
            image_urls=slide_urls,
            caption=row.get("caption") or "",
        )
    except Exception as exc:  # noqa: BLE001 — orchestrator catches all
        logger.exception("Carousel publish failed for %s", date_str)
        _record_failed(supabase, date_str, "carousel", _truncate(str(exc)))
        return False
    post_log.record_post(
        supabase, publish_date=date_str, media_type="carousel",
        status="published", ig_post_id=ig_post_id,
    )
    logger.info("Published carousel for %s: %s", date_str, ig_post_id)
    return True


def publish_reel_row(config: Config, supabase, row: dict) -> bool:
    """發布 reel（讀 VPS volume 上的 final.mp4）。"""
    date_str = row["publish_date"]
    if not config.instagram_enabled:
        logger.warning("Instagram not configured; skip reel %s", date_str)
        return False
    if not config.daily_video_dir:
        logger.warning("DAILY_VIDEO_DIR unset; cannot publish reel %s",
                       date_str)
        _record_failed(supabase, date_str, "reel", "no_video_dir")
        return False
    video_path = Path(config.daily_video_dir) / date_str / VIDEO_FILENAME
    if not video_path.is_file():
        logger.warning("No reel video at %s", video_path)
        _record_failed(supabase, date_str, "reel", f"no_video:{video_path}")
        return False
    try:
        ig_caption = reel_publisher.build_reel_caption(
            config, supabase, date_str, video_path.parent
        )
    except Exception as exc:  # noqa: BLE001 — orchestrator catches all
        logger.exception("Reel caption build failed for %s", date_str)
        _record_failed(supabase, date_str, "reel", _truncate(str(exc)))
        return False
    cover_url = None
    try:
        cover_url = reel_cover.build_cover_url(supabase, date_str)
    except Exception as exc:  # noqa: BLE001 — cover is best-effort
        logger.warning("Reel cover build failed (%s); using frame", exc)
    try:
        # 走 with_fallback 而非 instagram.publish_reel：rupload 偶發的泛型
        # ProcessingFailedError 要自動改走 video_url（F11），否則每次 Meta
        # 抽風都得人工補發。
        ig_post_id = reel_publisher.publish_reel_with_fallback(
            supabase,
            ig_user_id=config.ig_user_id,  # type: ignore[arg-type]
            access_token=config.meta_page_access_token,  # type: ignore[arg-type]
            video_path=video_path,
            ig_caption=ig_caption,
            cover_url=cover_url,
            date_str=date_str,
        )
    except Exception as exc:  # noqa: BLE001 — orchestrator catches all
        logger.exception("Reel publish failed for %s", date_str)
        _record_failed(supabase, date_str, "reel", _truncate(str(exc)))
        return False
    post_log.record_post(
        supabase, publish_date=date_str, media_type="reel",
        status="published", ig_post_id=ig_post_id,
    )
    logger.info("Published reel for %s: %s", date_str, ig_post_id)
    return True


def _record_failed(supabase, date_str: str, media_type: str, error: str) -> None:
    post_log.record_post(
        supabase, publish_date=date_str, media_type=media_type,
        status="failed", error=error,
    )


def _truncate(text: str, limit: int = 1000) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"
