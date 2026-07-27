"""render（HTML 產出）測試。"""
from lorescape_dashboard.render import (
    build_html,
    build_reels_html,
    health_signals,
    section_body,
    sparkline_svg,
)

DATA = {
    "generated_at": "2026-07-11 21:30",
    "backlog": {
        "epics": [
            {
                "id": "E1", "title": "補齊漏斗上層流量", "status": "進行中",
                "goal": "流量到穩定兩位數/天",
                "checkpoints": [
                    {"date": "2026-08-04", "text": "2026-08-04 回顧", "done": False, "days_left": 24}
                ],
                "features_total": 7, "features_done": 6,
            }
        ],
        "pending_deploy": {
            "title": "⚠️ 待部署",
            "items": [{"done": False, "text": "**App**：重新 build 送審"}],
        },
        "features": [
            {
                "id": "F1", "title": "IG 導流 CTA", "epic": "E1",
                "status": "已完成", "done": True,
                "tasks": [{"done": True, "text": "T1: x"}],
                "tasks_done": 1, "tasks_total": 1,
            },
            {
                "id": "F9", "title": "景點 SEO 著陸頁", "epic": "E1",
                "status": "進行中（首批已上線 2026-07-09）", "done": False,
                "tasks": [
                    {"done": True, "text": "T1: 建 place 路由"},
                    {"done": False, "text": "T3: 回看 GSC"},
                ],
                "tasks_done": 1, "tasks_total": 2,
            },
        ],
    },
    "deploys": {
        "services": [
            {"service": "backend", "deployed_at": "2026-07-09T15:12:04Z",
             "commit": "252411a", "behind_master": 43, "run_url": "https://x/1"},
            {"service": "landing", "deployed_at": None, "commit": None,
             "behind_master": None, "run_url": None},
        ]
    },
    "tests": {
        "suites": [
            {"suite": "frontend", "total": 552, "passed": 552, "failed": 0,
             "skipped": 0, "duration_seconds": 62.0, "coverage_percent": 73.5,
             "analyze": {"ok": True, "summary": "No issues found!"}, "failures": []},
            {"suite": "backend", "total": 169, "passed": 168, "failed": 1,
             "skipped": 0, "duration_seconds": 1.0,
             "failures": [{"name": "tests.test_a::test_bad", "error": "assert 1 == 2"}]},
        ]
    },
    "e2e": {
        "groups": [
            {"group": "patrol (integration_test/)", "file": "integration_test/app_test.dart",
             "cases": ["generate narration success"]},
        ],
        "total": 1,
    },
    "metrics": {
        "tabs": [
            {
                "name": "gsc", "latest_date": "2026-07-08",
                "headers": ["date", "clicks", "impressions"],
                "stats": {
                    "clicks": {"latest": 0.0, "week_ago": 0.0, "delta": 0.0},
                    "impressions": {"latest": 3.0, "week_ago": 1.0, "delta": 2.0},
                },
                "recent_rows": [["2026-07-08", "0", "3"]],
                "rows_30d": [["2026-07-07", "0", "1"], ["2026-07-08", "0", "3"]],
            }
        ],
        "ig_posts": [
            {"media_id": "222", "obs_date": "2026-07-11", "posted_date": "2026-07-08",
             "type": "REELS", "permalink": "https://ig/reel/b", "caption": "姬路城",
             "reach": "338", "likes": "6", "comments": "0", "saved": "0",
             "shares": "0", "total_interactions": "6", "views": "470",
             "avg_watch_time": "7000"},
            {"media_id": "111", "obs_date": "2026-07-11", "posted_date": "2026-07-03",
             "type": "CAROUSEL_ALBUM", "permalink": "https://ig/p/a", "caption": "紹修書院",
             "reach": "8", "likes": "3", "comments": "0", "saved": "0",
             "shares": "0", "total_interactions": "3", "views": "",
             "avg_watch_time": ""},
        ],
        "ig_reels": [
            {"media_id": "902", "posted_date": "2026-07-11",
             "permalink": "https://ig/reel/fuji", "caption": "富士山，供奉女神",
             "checkpoints": {
                 "24h": {"views": "165", "skip_rate_pct": "68.2",
                         "like_rate_pct": "1.4", "obs_date": "2026-07-12"},
             }},
            {"media_id": "901", "posted_date": "2026-07-05",
             "permalink": "https://ig/reel/cornwall", "caption": "康沃爾",
             "checkpoints": {
                 "24h": {"views": "120", "skip_rate_pct": "60.0",
                         "like_rate_pct": "1.0", "obs_date": "2026-07-06"},
                 "7d": {"views": "214", "reach": "168", "skip_rate_pct": "63.7",
                        "like_rate_pct": "0.0", "follower_pct": "6.1",
                        "age_25_34_pct": "35.7",
                        "countries": "日本:34.9|台灣:20.4",
                        "obs_date": "2026-07-12"},
             }},
        ],
    },
    "daily_story": {
        "date": "2026-07-11",
        "posts": [
            {"media_type": "carousel", "status": "published",
             "published_at": "2026-07-11T00:42:48+00:00", "ig_post_id": "179",
             "scheduled_at": None, "error": None, "review_decision": "approved"},
        ],
        "all_published": True,
    },
    "reels": {
        "entries": [
            {"date": "2026-07-11", "place": "富士山",
             "db_title": "Fujisan, sacred place", "category": "日本"},
            {"date": "2026-07-12", "place": "佩特拉", "db_title": "Petra", "category": "世界名勝"},
        ],
        "range": "2026/07/06 – 08/02",
    },
    "errors": {},
}


class TestHealthSignals:
    def test_四個燈號(self):
        signals = health_signals(DATA)
        by_label = {s["label"]: s for s in signals}
        assert by_label["測試"]["level"] == "critical"  # 有 1 失敗
        assert "720/721" in by_label["測試"]["value"]
        assert by_label["部署"]["level"] == "warning"
        assert by_label["今日故事"]["level"] == "good"
        assert "24" in by_label["Epic 檢核"]["value"]

    def test_全綠情境(self):
        data = {
            **DATA,
            "tests": {"suites": [{**DATA["tests"]["suites"][0]}]},
            "deploys": {"services": [{**DATA["deploys"]["services"][0], "behind_master": 0}]},
        }
        by_label = {s["label"]: s for s in health_signals(data)}
        assert by_label["測試"]["level"] == "good"
        assert by_label["部署"]["level"] == "good"


class TestSparkline:
    def test_產生_svg_路徑(self):
        svg = sparkline_svg([("2026-07-07", 1.0), ("2026-07-08", 3.0)])
        assert "<svg" in svg and "polyline" in svg

    def test_單點或無點回空字串(self):
        assert sparkline_svg([("2026-07-08", 3.0)]) == ""
        assert sparkline_svg([]) == ""


class TestBuildHtml:
    def test_含各區塊與資料(self):
        html = build_html(DATA)
        for text in [
            "產品面板", "2026-07-11 21:30",  # 標題與時間
            "E1", "倒數 24 天",              # epic
            "F9", "景點 SEO 著陸頁",          # 看板卡
            "backend", "落後 43",             # 部署
            "552/552", "test_bad",            # 測試與失敗
            "generate narration success",     # e2e
            "impressions",                    # metrics
            "carousel",                       # daily story
        ]:
            assert text in html, text

    def test_四個_tab_與對應面板(self):
        html = build_html(DATA)
        for key, label in [
            ("progress", "功能進度"), ("dev", "開發現況"),
            ("analytics", "數據分析"), ("story", "每日故事"),
        ]:
            assert f'data-tab="{key}"' in html
            assert label in html
            assert f'id="tab-{key}"' in html
        # 分組正確：backlog 在 progress、tests 在 dev、metrics 在 analytics、
        # 每日故事與 reels 在 story
        progress = html.split('id="tab-progress"')[1].split('id="tab-dev"')[0]
        dev = html.split('id="tab-dev"')[1].split('id="tab-analytics"')[0]
        analytics = html.split('id="tab-analytics"')[1].split('id="tab-story"')[0]
        story = html.split('id="tab-story"')[1]
        assert "F9" in progress and "552/552" not in progress
        assert "552/552" in dev and "impressions" not in dev
        assert "impressions" in analytics and "carousel" not in analytics
        assert "carousel" in story and "富士山" in story

    def test_reels_今日景點與未來排程(self):
        html = build_html(DATA)  # generated_at 2026-07-11
        story = html.split('id="tab-story"')[1]
        assert "今日景點：富士山" in story
        assert "佩特拉" in story  # 未來 7 天
        assert "完整排程" in story

    def test_看板_已完成與進行中分欄(self):
        html = build_html(DATA)
        assert "進行中" in html and "已完成" in html

    def test_區塊錯誤顯示錯誤卡(self):
        data = {**DATA, "metrics": None, "errors": {"metrics": "no credentials"}}
        assert "no credentials" in build_html(data)

    def test_section_body_可獨立渲染並帶資料時間(self):
        data = {**DATA, "collected_at": {"deploys": "2026-07-11 16:00"}}
        body = section_body("deploys", data)
        assert "backend" in body and "<section" not in body
        assert "資料時間：2026-07-11 16:00" in body
        # 無資料的區塊回錯誤卡
        assert "boom" in section_body("metrics", {**DATA, "metrics": None, "errors": {"metrics": "boom"}})

    def test_metrics_含_ig_每貼文表格(self):
        body = section_body("metrics", DATA)
        assert "IG 貼文成效" in body
        assert 'href="https://ig/reel/b"' in body
        assert "姬路城" in body
        # avg_watch_time 毫秒 → 秒顯示；空值顯示 –
        assert "7.0s" in body
        assert "REELS" in body and "CAROUSEL_ALBUM" in body

    def test_metrics_無_ig_posts_不長表格(self):
        data = {**DATA, "metrics": {"tabs": DATA["metrics"]["tabs"]}}
        assert "IG 貼文成效" not in section_body("metrics", data)

    def test_metrics_含_reels_洞察快照表格(self):
        body = section_body("metrics", DATA)
        assert "Reels 洞察快照" in body
        assert 'href="https://ig/reel/cornwall"' in body
        # 24h 與 7d 快照數值都在同一列呈現
        assert "60.0%" in body and "63.7%" in body
        # 富士山缺 48h/7d → 以 – 補位
        assert "–" in body

    def test_metrics_無_ig_reels_不長快照表格(self):
        data = {
            **DATA,
            "metrics": {
                "tabs": DATA["metrics"]["tabs"],
                "ig_posts": DATA["metrics"]["ig_posts"],
            },
        }
        assert "Reels 洞察快照" not in section_body("metrics", data)

    def test_快照卡連到獨立明細頁(self):
        body = section_body("metrics", DATA)
        assert 'href="reels.html"' in body

    def test_html_跳脫(self):
        data = {
            **DATA,
            "tests": {
                "suites": [
                    {**DATA["tests"]["suites"][1],
                     "failures": [{"name": "t<script>", "error": "a<b & c"}]}
                ]
            },
        }
        html = build_html(data)
        assert "t<script>" not in html
        assert "t&lt;script&gt;" in html


class TestBuildReelsHtml:
    def test_每支_reel_一張卡_指標列乘_checkpoint_欄(self):
        html = build_reels_html(DATA)
        assert "Reels 洞察明細" in html
        assert 'href="https://ig/reel/cornwall"' in html
        assert "略過率" in html and "63.7%" in html
        # 24h 缺觸及、7d 有 → 同列以 – 補位仍呈現
        assert "觸及帳號" in html and "168" in html
        # 觀眾輪廓
        assert "年齡 25-34" in html and "35.7%" in html
        # 國家分布仍收集進 CSV，但明細表暫不顯示
        assert "國家分布" not in html and "日本 34.9%" not in html

    def test_整列皆空的指標不顯示(self):
        html = build_reels_html(DATA)
        assert "性別・男" not in html

    def test_回主面板連結(self):
        html = build_reels_html(DATA)
        assert 'href="index.html"' in html

    def test_無資料顯示提示(self):
        data = {**DATA, "metrics": {"tabs": []}}
        html = build_reels_html(data)
        assert "還沒有 Reels 洞察快照" in html
