"""Instagram Graph API client tests."""
from __future__ import annotations

from unittest.mock import patch

import pytest

from lorescape_publisher.instagram import (
    ReelUploadGenericError,
    publish,
    publish_carousel,
    publish_reel,
    publish_reel_from_url,
)


def test_publish_creates_container_then_publishes(requests_mock):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "container-1"},
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "ig-post-1"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        post_id = publish(
            ig_user_id="ig1",
            access_token="tok",
            image_url="https://example.com/x.jpg",
            caption="my caption",
        )

    assert post_id == "ig-post-1"
    create_req = requests_mock.request_history[0]
    assert create_req.qs["image_url"] == ["https://example.com/x.jpg"]
    assert create_req.qs["caption"] == ["my caption"]
    assert create_req.qs["access_token"] == ["tok"]

    publish_req = requests_mock.request_history[1]
    assert publish_req.qs["creation_id"] == ["container-1"]


def test_publish_carousel_creates_children_then_parent_then_publishes(
    requests_mock,
):
    # All /media POSTs hit the same URL; queue distinct ids in call order:
    # three children, then the parent CAROUSEL container.
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        [
            {"json": {"id": "child-1"}},
            {"json": {"id": "child-2"}},
            {"json": {"id": "child-3"}},
            {"json": {"id": "parent-1"}},
        ],
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "ig-carousel-1"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        post_id = publish_carousel(
            ig_user_id="ig1",
            access_token="tok",
            image_urls=[
                "https://example.com/1.png",
                "https://example.com/2.png",
                "https://example.com/3.png",
            ],
            caption="carousel caption",
        )

    assert post_id == "ig-carousel-1"

    history = requests_mock.request_history
    # 3 children + 1 parent + 1 publish = 5 calls
    assert len(history) == 5

    # Each child container is flagged as a carousel item, carries its image,
    # and does NOT carry the caption.
    for i, url in enumerate(
        ["https://example.com/1.png", "https://example.com/2.png",
         "https://example.com/3.png"]
    ):
        child_req = history[i]
        assert child_req.qs["is_carousel_item"] == ["true"]
        assert child_req.qs["image_url"] == [url]
        assert "caption" not in child_req.qs

    parent_req = history[3]
    assert parent_req.qs["media_type"] == ["carousel"]
    assert parent_req.qs["children"] == ["child-1,child-2,child-3"]
    assert parent_req.qs["caption"] == ["carousel caption"]

    publish_req = history[4]
    assert publish_req.qs["creation_id"] == ["parent-1"]


def test_publish_carousel_rejects_empty_image_list():
    with pytest.raises(ValueError):
        publish_carousel(
            ig_user_id="ig1", access_token="tok",
            image_urls=[], caption="c",
        )


def test_publish_raises_on_http_error(requests_mock):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        status_code=400,
        json={"error": {"message": "Image not reachable"}},
    )
    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError, match="Image not reachable"):
            publish(
                ig_user_id="ig1", access_token="tok",
                image_url="bad", caption="c",
            )


def test_publish_container_http_error_includes_response_body(requests_mock):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media", json={"id": "c-1"}
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        status_code=400,
        json={"error": {"message": "Media ID is not available"}},
    )
    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError, match="Media ID is not available"):
            publish(
                ig_user_id="ig1", access_token="tok",
                image_url="https://example.com/x.jpg", caption="c",
            )


def test_reel_container_http_error_carries_body_not_request_url(
    requests_mock, tmp_path
):
    """The 2026-08-13 incident: container creation 400'd and the recorded
    error was `requests`' "for url: <the whole request URL>" — the URL-encoded
    caption crowded the real reason out of social_posts.error (1000 chars).
    The message must carry the API's body and not the request URL."""
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")
    long_caption = "毗奢耶那伽羅，僅次於北京的世界第二大城。" * 20

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        status_code=400,
        json={
            "error": {
                "message": "The cover URL is not reachable",
                "code": 100,
                "error_subcode": 2207052,
            }
        },
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError) as ei:
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption=long_caption,
                cover_url="https://example.com/cover.png",
            )

    message = str(ei.value)
    assert "The cover URL is not reachable" in message
    assert "2207052" in message
    # Neither the caption nor the credentials may ride along in the message —
    # that is exactly what pushed the reason out of the stored error.
    assert long_caption not in message
    assert "access_token" not in message
    assert len(message) < 500


def test_publish_reel_from_url_http_error_includes_response_body(
    requests_mock,
):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        status_code=400,
        json={"error": {"message": "video_url is not reachable"}},
    )
    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError, match="video_url is not reachable"):
            publish_reel_from_url(
                ig_user_id="ig1",
                access_token="tok",
                video_url="https://example.com/final.mp4",
                caption="c",
            )


def test_container_poll_http_error_includes_response_body(
    requests_mock, tmp_path
):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media", json={"id": "poll-c"}
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/poll-c",
        json={"success": True},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/poll-c",
        status_code=400,
        json={"error": {"message": "Unsupported get request"}},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError, match="Unsupported get request"):
            publish_reel(
                ig_user_id="ig1", access_token="tok",
                video_path=str(video), caption="c",
            )


def test_error_body_is_capped_so_one_html_page_cannot_flood_the_log(
    requests_mock,
):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        status_code=502,
        text="<html>" + "x" * 5000 + "</html>",
    )
    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError) as ei:
            publish(
                ig_user_id="ig1", access_token="tok",
                image_url="https://example.com/x.jpg", caption="c",
            )
    assert len(str(ei.value)) < 700


def test_publish_reel_runs_create_upload_poll_publish(requests_mock, tmp_path):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"fake-bytes")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-1"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-1",
        json={"success": True},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/reel-container-1",
        json={"status_code": "FINISHED"},
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "reel-post-1"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        post_id = publish_reel(
            ig_user_id="ig1",
            access_token="tok",
            video_path=str(video),
            caption="my reel caption",
        )

    assert post_id == "reel-post-1"

    create_req = requests_mock.request_history[0]
    assert create_req.qs["media_type"] == ["reels"]
    assert create_req.qs["upload_type"] == ["resumable"]
    assert create_req.qs["caption"] == ["my reel caption"]

    upload_req = requests_mock.request_history[1]
    assert upload_req.headers["Authorization"] == "OAuth tok"
    assert upload_req.headers["offset"] == "0"
    assert upload_req.headers["file_size"] == "10"
    assert upload_req.body == b"fake-bytes"

    publish_req = requests_mock.request_history[-1]
    assert publish_req.qs["creation_id"] == ["reel-container-1"]


def test_publish_reel_passes_cover_url_when_provided(requests_mock, tmp_path):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"v")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-c"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-c",
        json={"success": True},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/reel-c",
        json={"status_code": "FINISHED"},
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "reel-post"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        publish_reel(
            ig_user_id="ig1",
            access_token="tok",
            video_path=str(video),
            caption="c",
            cover_url="https://example.com/cover.png",
        )

    create_req = requests_mock.request_history[0]
    assert create_req.qs["cover_url"] == ["https://example.com/cover.png"]


def test_publish_reel_omits_cover_url_when_none(requests_mock, tmp_path):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"v")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media", json={"id": "reel-c"}
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-c",
        json={"success": True},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/reel-c",
        json={"status_code": "FINISHED"},
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "reel-post"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        publish_reel(
            ig_user_id="ig1", access_token="tok",
            video_path=str(video), caption="c",
        )

    assert "cover_url" not in requests_mock.request_history[0].qs


def test_publish_reel_raises_when_container_errors(requests_mock, tmp_path):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-2"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-2",
        json={"success": True},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/reel-container-2",
        json={"status_code": "ERROR", "status": "Video aspect ratio invalid"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError) as exc_info:
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption="c",
            )
    assert "Video aspect ratio invalid" in str(exc_info.value)


def test_publish_reel_raises_when_upload_rejected(requests_mock, tmp_path):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-3"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-3",
        json={"success": False, "error": "rejected"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError, match="not accepted"):
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption="c",
            )


def test_publish_reel_upload_http_error_includes_response_body(
    requests_mock, tmp_path
):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-4"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-4",
        status_code=400,
        json={
            "debug_info": {
                "type": "ProcessingFailedError",
                "message": "Video Transcoding Error",
            }
        },
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(Exception, match="Video Transcoding Error") as ei:
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption="c",
            )
    # A content-specific rejection must NOT look retriable-via-URL.
    assert not isinstance(ei.value, ReelUploadGenericError)


def test_publish_reel_generic_processing_failure_raises_typed_error(
    requests_mock, tmp_path
):
    """The 2026-07-12 rupload endpoint failure: generic body → typed error
    so callers can fall back to the video_url path (BACKLOG F11)."""
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-5"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-5",
        status_code=400,
        json={
            "debug_info": {
                "retriable": False,
                "type": "ProcessingFailedError",
                "message": "Request processing failed",
            }
        },
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(ReelUploadGenericError, match="reel-container-5"):
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption="c",
            )


def test_publish_reel_non_json_error_body_is_not_generic(
    requests_mock, tmp_path
):
    video = tmp_path / "final.mp4"
    video.write_bytes(b"x")

    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "reel-container-6"},
    )
    requests_mock.post(
        "https://rupload.facebook.com/ig-api-upload/v21.0/reel-container-6",
        status_code=500,
        text="Internal Server Error",
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        with pytest.raises(RuntimeError) as ei:
            publish_reel(
                ig_user_id="ig1",
                access_token="tok",
                video_path=str(video),
                caption="c",
            )
    assert not isinstance(ei.value, ReelUploadGenericError)


def test_publish_reel_from_url_creates_url_container_then_publishes(
    requests_mock,
):
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media",
        json={"id": "url-container-1"},
    )
    requests_mock.get(
        "https://graph.facebook.com/v21.0/url-container-1",
        json={"status_code": "FINISHED"},
    )
    requests_mock.post(
        "https://graph.facebook.com/v21.0/ig1/media_publish",
        json={"id": "reel-post-url-1"},
    )

    with patch("lorescape_publisher.instagram.time.sleep"):
        post_id = publish_reel_from_url(
            ig_user_id="ig1",
            access_token="tok",
            video_url="https://example.com/reel-videos/d/final.mp4",
            caption="url caption",
            cover_url="https://example.com/cover.png",
        )

    assert post_id == "reel-post-url-1"

    create_req = requests_mock.request_history[0]
    assert create_req.qs["media_type"] == ["reels"]
    assert create_req.qs["video_url"] == [
        "https://example.com/reel-videos/d/final.mp4"
    ]
    assert create_req.qs["cover_url"] == ["https://example.com/cover.png"]
    assert create_req.qs["caption"] == ["url caption"]
    # video_url mode never touches the rupload endpoint or upload_type.
    assert "upload_type" not in create_req.qs
    assert all(
        "rupload.facebook.com" not in r.url
        for r in requests_mock.request_history
    )

    publish_req = requests_mock.request_history[-1]
    assert publish_req.qs["creation_id"] == ["url-container-1"]
