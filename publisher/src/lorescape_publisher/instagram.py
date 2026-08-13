"""Instagram Business publishing via the Meta Graph API.

Two-step pattern: create a media container, then publish.
The IG Business account must be linked to a Facebook Page, and the access
token must be a long-lived Page access token with `instagram_content_publish`.

Reference: https://developers.facebook.com/docs/instagram-api/guides/content-publishing
"""
from __future__ import annotations

import json
import logging
import os
import time

import requests

logger = logging.getLogger(__name__)


class ReelUploadGenericError(RuntimeError):
    """rupload rejected the bytes with its *generic* ProcessingFailedError.

    This is an endpoint-side failure, not a problem with the video itself
    (content-specific rejections like transcoding errors raise a plain
    RuntimeError instead), so retrying via `publish_reel_from_url` — where
    Meta fetches the video from a public URL and rupload is bypassed — can
    succeed. Observed 2026-07-12; see BACKLOG F11.
    """

META_GRAPH_API = "https://graph.facebook.com/v21.0"
_REQUEST_TIMEOUT = 30
_ERROR_BODY_LIMIT = 500
_CONTAINER_READY_DELAY_SECONDS = 5
RUPLOAD_API = "https://rupload.facebook.com/ig-api-upload/v21.0"
_UPLOAD_TIMEOUT = 300
_REEL_POLL_INTERVAL_SECONDS = 5
_REEL_POLL_MAX_ATTEMPTS = 60


def _check_ok(response, action: str) -> None:
    """`raise_for_status()` that keeps the body and drops the request URL.

    Graph API puts the actual reason (`error.message`, `error_subcode`) in the
    response body, which `raise_for_status()` discards in favour of the request
    URL. For reels that URL is mostly the URL-encoded caption, so the recorded
    `social_posts.error` was all URL and no reason (2026-08-13, ISSUES.md) —
    and it carries the access token, which has no business in a log.
    """
    if response.status_code < 400:
        return
    body = response.text or ""
    if len(body) > _ERROR_BODY_LIMIT:
        body = body[: _ERROR_BODY_LIMIT - 1] + "…"
    raise RuntimeError(
        f"{action} failed with HTTP {response.status_code}: {body}"
    )


def publish(
    *,
    ig_user_id: str,
    access_token: str,
    image_url: str,
    caption: str,
) -> str:
    """Create + publish an IG single-image post. Returns the IG post id.

    Caller is responsible for ensuring `image_url` is publicly reachable —
    Meta servers fetch the image directly, they do not accept uploads.
    """
    container_id = _create_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        image_url=image_url,
        caption=caption,
    )
    time.sleep(_CONTAINER_READY_DELAY_SECONDS)
    return _publish_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        container_id=container_id,
    )


def publish_carousel(
    *,
    ig_user_id: str,
    access_token: str,
    image_urls: list[str],
    caption: str,
) -> str:
    """Create + publish a multi-image IG carousel post. Returns the post id.

    Three-step pattern: create one child container per image
    (`is_carousel_item=true`), then a parent `CAROUSEL` container listing the
    children, then publish the parent. As with `publish`, Meta fetches each
    `image_url` directly, so they must be publicly reachable.
    """
    if not image_urls:
        raise ValueError("publish_carousel requires at least one image_url")

    child_ids = [
        _create_carousel_item(
            ig_user_id=ig_user_id,
            access_token=access_token,
            image_url=url,
        )
        for url in image_urls
    ]
    parent_id = _create_carousel_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        child_ids=child_ids,
        caption=caption,
    )
    time.sleep(_CONTAINER_READY_DELAY_SECONDS)
    return _publish_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        container_id=parent_id,
    )


def _create_carousel_item(
    *, ig_user_id: str, access_token: str, image_url: str
) -> str:
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media",
        params={
            "image_url": image_url,
            "is_carousel_item": "true",
            "access_token": access_token,
        },
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, "Carousel item container creation")
    return response.json()["id"]


def _create_carousel_container(
    *,
    ig_user_id: str,
    access_token: str,
    child_ids: list[str],
    caption: str,
) -> str:
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media",
        params={
            "media_type": "CAROUSEL",
            "children": ",".join(child_ids),
            "caption": caption,
            "access_token": access_token,
        },
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, "Carousel parent container creation")
    return response.json()["id"]


def _create_container(
    *,
    ig_user_id: str,
    access_token: str,
    image_url: str,
    caption: str,
) -> str:
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media",
        params={
            "image_url": image_url,
            "caption": caption,
            "access_token": access_token,
        },
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, "Image container creation")
    return response.json()["id"]


def _publish_container(
    *, ig_user_id: str, access_token: str, container_id: str
) -> str:
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media_publish",
        params={
            "creation_id": container_id,
            "access_token": access_token,
        },
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, f"Publishing container {container_id}")
    return response.json()["id"]


def publish_reel(
    *,
    ig_user_id: str,
    access_token: str,
    video_path: str,
    caption: str,
    cover_url: str | None = None,
) -> str:
    """Create + resumable-upload + publish an IG Reel. Returns the IG post id.

    Uploads the local video bytes directly to Meta's resumable upload
    endpoint — no public URL or intermediate storage is needed.

    `cover_url`, when given, is a publicly reachable image Meta uses as the
    Reel's cover (grid thumbnail). Omitted → Meta auto-picks a video frame.
    """
    container_id = _create_reel_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        caption=caption,
        cover_url=cover_url,
    )
    _upload_reel_bytes(
        container_id=container_id,
        access_token=access_token,
        video_path=video_path,
    )
    _wait_until_finished(container_id=container_id, access_token=access_token)
    return _publish_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        container_id=container_id,
    )


def publish_reel_from_url(
    *,
    ig_user_id: str,
    access_token: str,
    video_url: str,
    caption: str,
    cover_url: str | None = None,
) -> str:
    """Create + publish an IG Reel from a public video URL. Returns post id.

    Bypasses the rupload endpoint entirely: Meta fetches `video_url` itself,
    so the URL must be publicly reachable until the container reaches
    FINISHED. Used as the fallback when rupload fails generically
    (`ReelUploadGenericError`).
    """
    params = {
        "media_type": "REELS",
        "video_url": video_url,
        "caption": caption,
        "access_token": access_token,
    }
    if cover_url:
        params["cover_url"] = cover_url
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media",
        params=params,
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, "Reel container creation (video_url)")
    container_id = response.json()["id"]
    _wait_until_finished(container_id=container_id, access_token=access_token)
    return _publish_container(
        ig_user_id=ig_user_id,
        access_token=access_token,
        container_id=container_id,
    )


def _create_reel_container(
    *,
    ig_user_id: str,
    access_token: str,
    caption: str,
    cover_url: str | None = None,
) -> str:
    params = {
        "media_type": "REELS",
        "upload_type": "resumable",
        "caption": caption,
        "access_token": access_token,
    }
    if cover_url:
        params["cover_url"] = cover_url
    response = requests.post(
        f"{META_GRAPH_API}/{ig_user_id}/media",
        params=params,
        timeout=_REQUEST_TIMEOUT,
    )
    _check_ok(response, "Reel container creation (resumable)")
    return response.json()["id"]


def _upload_reel_bytes(
    *, container_id: str, access_token: str, video_path: str
) -> None:
    file_size = os.path.getsize(video_path)
    with open(video_path, "rb") as video_file:
        video_bytes = video_file.read()
    response = requests.post(
        f"{RUPLOAD_API}/{container_id}",
        headers={
            "Authorization": f"OAuth {access_token}",
            "Content-Type": "application/octet-stream",
            "offset": "0",
            "file_size": str(file_size),
        },
        data=video_bytes,
        timeout=_UPLOAD_TIMEOUT,
    )
    if response.status_code >= 400:
        # rupload puts the real failure reason (e.g. transcoding errors) in
        # the response body, which raise_for_status() would discard.
        message = (
            f"Reel upload failed with HTTP {response.status_code} for "
            f"container {container_id}: {response.text}"
        )
        if _is_generic_processing_failure(response.text):
            raise ReelUploadGenericError(message)
        raise RuntimeError(message)
    body = response.json()
    if not body.get("success", True):
        raise RuntimeError(f"Reel upload was not accepted: {body}")


def _is_generic_processing_failure(body: str) -> bool:
    """True only for rupload's generic ProcessingFailedError body.

    Content-specific rejections (e.g. "Video Transcoding Error: … failed to
    transcode") share the same `type` but carry a concrete message; the
    video_url fallback cannot save those, so they must return False.
    """
    try:
        debug = json.loads(body).get("debug_info") or {}
    except (ValueError, AttributeError):
        return False
    message = str(debug.get("message", "")).lower()
    return (
        debug.get("type") == "ProcessingFailedError"
        and "request processing failed" in message
    )


def _wait_until_finished(*, container_id: str, access_token: str) -> None:
    for _ in range(_REEL_POLL_MAX_ATTEMPTS):
        response = requests.get(
            f"{META_GRAPH_API}/{container_id}",
            params={
                "fields": "status_code,status",
                "access_token": access_token,
            },
            timeout=_REQUEST_TIMEOUT,
        )
        _check_ok(response, f"Polling container {container_id}")
        payload = response.json()
        status = payload.get("status_code")
        if status == "FINISHED":
            return
        if status in ("ERROR", "EXPIRED"):
            detail = payload.get("status", "")
            raise RuntimeError(
                f"Reel container {container_id} failed: "
                f"{status} {detail}".strip()
            )
        time.sleep(_REEL_POLL_INTERVAL_SECONDS)
    raise TimeoutError(
        f"Reel container {container_id} not ready after polling"
    )
