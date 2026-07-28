# 地球儀首頁與導覽重組 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Lorescape App 首頁換成釘著每日故事地點的手繪風地球儀，拿掉 bottom navigator，歷程與設定改由首頁右上角 icon 進入，定位與搜尋則 zoom in 到既有的詳細地圖。

**Architecture:** 新增 `lib/features/home/` feature，內含純 Dart 的正射投影與世界輪廓解析（domain）與 `CustomPaint` 地球儀（presentation）。`MainScreen` 四分頁刪除，改成 `/`、`/map`、`/journey`、`/settings` 四個扁平路由，`/map` 用 `CustomTransitionPage` 讓首頁在 `secondaryAnimation` 下 scale-out 淡出。每日故事座標由 `daily_story_places` 新增的 `latitude` / `longitude` 欄位提供。

**Tech Stack:** Flutter（fvm）、Riverpod、go_router、latlong2、Supabase、Python（uv，backfill 腳本）。

## Global Constraints

- 一律用 `fvm` 執行 flutter / dart 指令，例如 `fvm flutter test`、`fvm flutter analyze --fatal-infos`。
- 每個 task 收尾前 `fvm flutter analyze --fatal-infos` 必須零問題。
- 依賴規則（守門測試 `frontend/test/architecture/dependency_rules_test.dart`）：feature 之間只能跨引他 feature 的 `domain/` 與 `providers.dart`；`app/` 僅得以 composition root（`lib/app/config/router_config.dart`、`lib/app/shell/`）引用 features；feature 內 `domain/` 不得引用任何 `presentation/` 或 `data/`。
- widget test 一律用 `test/helpers/pump_app.dart` 的 `pumpScreen` / `pumpRouterApp`，測試名稱寫成 `given X, when Y, then Z`，用 `test/fakes/` 的 fake 而非 mocktail。
- `pumpScreen` / `pumpRouterApp` 掛的是空 asset loader，`tr()` 會回傳原始 key，斷言請對 key（例如 `'home.badge_latest'`）。
- 文件與註解以繁體中文撰寫（技術名詞除外）。
- 設計色票一律讀 `context.tokens`（`lib/app/config/lorescape_tokens.dart`），不要在 widget 裡重新寫死色碼。地球儀專屬的插畫色（海 `#FCF8ED`、陸 `#CBD8A9`、網格 `rgba(111,124,86,.17)`、陸地描邊 `rgba(101,116,74,.42)`、小點 `#5F7148`、標籤字 `#6E6350`）不在 tokens 內，集中宣告成 `GlobePalette` 常數。
- 提交訊息用 conventional commits，scope 用資料夾名（`feat(home): …`、`fix(explore): …`）。

---

## File Structure

新增：

| 檔案 | 責任 |
|---|---|
| `supabase/migrations/20260728000000_grant_place_coords_select.sql` | 開放既有 `latitude` / `longitude` 欄位的 select 權限給 anon/authenticated |
| `scripts/backfill_place_coords.py` | 從 Wikidata P625 補座標 |
| `scripts/tests/test_backfill_place_coords.py` | 上述腳本的純函式測試 |
| `frontend/tool/build_world_outline.py` | 把 Natural Earth GeoJSON 壓成 App 用的緊湊格式 |
| `frontend/assets/geo/world_land_110m.json` | 產出的世界陸地輪廓（進版控） |
| `frontend/lib/features/home/domain/globe/globe_rotation.dart` | 地球儀旋轉角值物件 |
| `frontend/lib/features/home/domain/globe/orthographic_projection.dart` | 正射投影、可見性、地平線裁切 |
| `frontend/lib/features/home/domain/globe/world_outline.dart` | 輪廓資料模型與解析 |
| `frontend/lib/features/home/domain/models/globe_pin.dart` | 地球儀上的一個釘點 |
| `frontend/lib/features/home/providers.dart` | home feature 的公開介面 |
| `frontend/lib/features/home/presentation/widgets/globe_palette.dart` | 地球儀插畫色 |
| `frontend/lib/features/home/presentation/widgets/globe_painter.dart` | `CustomPainter` 本體 |
| `frontend/lib/features/home/presentation/widgets/globe_view.dart` | 地球儀 widget（拖曳、飛行動畫、pin/chip 疊層） |
| `frontend/lib/features/home/presentation/widgets/story_rail.dart` | 底部每日故事橫向卡片列 |
| `frontend/lib/features/home/presentation/widgets/home_top_bar.dart` | 頂部字標列與搜尋 bar、建議清單 |
| `frontend/lib/features/home/presentation/screens/globe_home_screen.dart` | 首頁組裝 |
| `frontend/lib/shared/widgets/journal/floating_back_button.dart` | 歷程／設定用的浮動返回鈕 |

修改：

| 檔案 | 改動 |
|---|---|
| `frontend/pubspec.yaml` | assets 加 `assets/geo/` |
| `frontend/lib/features/daily_story/domain/models/daily_story.dart` | 加 `latitude` / `longitude` |
| `frontend/lib/features/daily_story/data/supabase_daily_story_repository.dart` | join 與映射加座標 |
| `frontend/lib/features/explore/data/services/wikipedia_places_service.dart` | 加 `suggestTitles` |
| `frontend/lib/features/explore/domain/repositories/places_repository.dart` | 加 `suggestPlaceNames` |
| `frontend/lib/features/explore/data/repositories/places_repository_impl.dart` | 實作 `suggestPlaceNames` |
| `frontend/lib/features/explore/data/repositories/caching_places_repository.dart` | 委派 `suggestPlaceNames` |
| `frontend/lib/features/explore/providers.dart` | 加 `placeSuggestionsProvider` |
| `frontend/lib/features/explore/presentation/screens/explore_screen.dart` | 加 `initialQuery`、左上地球儀返回鈕 |
| `frontend/lib/features/journey/presentation/screens/journey_screen.dart` | 加浮動返回鈕 |
| `frontend/lib/features/settings/presentation/screens/settings_screen.dart` | 加浮動返回鈕 |
| `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart` | `/?tab=explore` → `/map` |
| `frontend/lib/app/config/router_config.dart` | 扁平路由與轉場 |
| `frontend/assets/translations/zh-TW.json`、`en.json` | 加 `home.*`、`explore.back_to_globe`，移除 `bottom_nav.*` 與 `story.list_*` |
| `frontend/test/fakes/fake_places_repository.dart` | 加 `suggestPlaceNames` |

刪除：`frontend/lib/app/shell/main_screen.dart`、`frontend/lib/features/daily_story/presentation/screens/story_list_screen.dart`、`frontend/test/app/shell/main_screen_test.dart`、`frontend/test/features/daily_story/presentation/screens/story_list_screen_test.dart`。

---

### Task 1: `daily_story_places` 座標欄位與 backfill 腳本

**Files:**
- Create: `supabase/migrations/20260728000000_grant_place_coords_select.sql`
- Create: `scripts/backfill_place_coords.py`
- Test: `scripts/tests/test_backfill_place_coords.py`

**Interfaces:**
- Consumes: 無。
- Produces: `daily_story_places.latitude` / `daily_story_places.longitude`（既有欄位，型別 `numeric`，nullable）新增開放給 anon/authenticated 的 select 權限。Task 2 的 App 端查詢依賴這兩欄可讀。

- [ ] **Step 1: 寫 migration**

建立 `supabase/migrations/20260728000000_grant_place_coords_select.sql`：

```sql
-- `daily_story_places.latitude` / `longitude`（型別 numeric）早在
-- 20260521120000 就為 IG 圖卡功能加過，是 admin 人工填的欄位；
-- publisher/src/lorescape_publisher/card/mapper.py 讀這兩欄把座標渲染到
-- 圖卡上。20260527000000 曾明文把它們列為 operational、admin-only 欄位，
-- 刻意不 grant 給 anon/authenticated。
--
-- 這裡刻意推翻那個決定：v3 地球儀首頁要把每日故事釘在地圖上，App 端
-- 也需要讀這兩欄。座標本身沿用既有欄位、不新增欄位也不改型別，
-- 圖卡渲染與地球儀首頁共用同一組座標。
-- 既有列若還沒被圖卡流程填過座標，由
-- scripts/backfill_place_coords.py 依 wikidata_id 查 P625 補齊，
-- 補不到的維持 null——App 端會照常在卡片列顯示，只是不釘上地球儀。
grant select (latitude, longitude)
  on table public.daily_story_places to anon, authenticated;
```

- [ ] **Step 2: 寫 backfill 腳本的失敗測試**

建立 `scripts/tests/test_backfill_place_coords.py`：

```python
from backfill_place_coords import coords_from_entity


def test_reads_p625_from_entity():
    entity = {
        "claims": {
            "P625": [
                {
                    "mainsnak": {
                        "datavalue": {
                            "value": {"latitude": 41.9022, "longitude": 12.4539}
                        }
                    }
                }
            ]
        }
    }
    assert coords_from_entity(entity) == (41.9022, 12.4539)


def test_returns_none_when_no_p625():
    assert coords_from_entity({"claims": {}}) is None


def test_returns_none_when_claim_is_malformed():
    entity = {"claims": {"P625": [{"mainsnak": {"snaktype": "novalue"}}]}}
    assert coords_from_entity(entity) is None
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd scripts && uv run pytest tests/test_backfill_place_coords.py -v`
Expected: FAIL，`ModuleNotFoundError: No module named 'backfill_place_coords'`

- [ ] **Step 4: 寫腳本**

建立 `scripts/backfill_place_coords.py`：

```python
"""把 daily_story_places 缺的經緯度從 Wikidata P625 補回來。

用法：
    cd scripts && uv run python backfill_place_coords.py [--dry-run]

只處理 wikidata_id 非 null 且 latitude 為 null 的列。查不到座標的列會在
最後印成一份清單，需要人工到 Supabase Dashboard 補。
"""

from __future__ import annotations

import argparse
import sys

import requests
from dotenv import load_dotenv
from lorescape_publisher.config import Config
from supabase import create_client

_WIKIDATA_ENTITY_URL = "https://www.wikidata.org/wiki/Special:EntityData/{qid}.json"
_USER_AGENT = "Lorescape/1.0 (https://lorescape.app; ops@lorescape.app)"


def coords_from_entity(entity: dict) -> tuple[float, float] | None:
    """從一個 Wikidata entity 的 claims 取出 (latitude, longitude)。

    沒有 P625、或 claim 結構不完整（例如 snaktype 是 novalue）時回傳 None。
    """
    claims = entity.get("claims") or {}
    for claim in claims.get("P625") or []:
        value = ((claim.get("mainsnak") or {}).get("datavalue") or {}).get("value")
        if not isinstance(value, dict):
            continue
        lat = value.get("latitude")
        lon = value.get("longitude")
        if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
            return (float(lat), float(lon))
    return None


def fetch_entity(qid: str) -> dict | None:
    response = requests.get(
        _WIKIDATA_ENTITY_URL.format(qid=qid),
        headers={"User-Agent": _USER_AGENT},
        timeout=20,
    )
    if response.status_code != 200:
        return None
    entities = response.json().get("entities") or {}
    return entities.get(qid)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_dotenv()
    config = Config.from_env()
    supabase = create_client(config.supabase_url, config.supabase_service_role_key)

    rows = (
        supabase.table("daily_story_places")
        .select("id, name, wikidata_id")
        .is_("latitude", "null")
        .not_.is_("wikidata_id", "null")
        .execute()
        .data
    )
    print(f"待補座標的景點：{len(rows)} 筆")

    unresolved: list[str] = []
    for row in rows:
        entity = fetch_entity(row["wikidata_id"])
        coords = coords_from_entity(entity) if entity else None
        if coords is None:
            unresolved.append(f'{row["name"]} ({row["wikidata_id"]})')
            continue
        lat, lon = coords
        print(f'  {row["name"]}: {lat}, {lon}')
        if not args.dry_run:
            supabase.table("daily_story_places").update(
                {"latitude": lat, "longitude": lon}
            ).eq("id", row["id"]).execute()

    missing_qid = (
        supabase.table("daily_story_places")
        .select("name")
        .is_("latitude", "null")
        .is_("wikidata_id", "null")
        .execute()
        .data
    )
    for row in missing_qid:
        unresolved.append(f'{row["name"]} (沒有 wikidata_id)')

    if unresolved:
        print("\n需要人工補座標：")
        for item in unresolved:
            print(f"  - {item}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd scripts && uv run pytest tests/test_backfill_place_coords.py -v`
Expected: 3 passed

- [ ] **Step 6: 提交**

```bash
git add supabase/migrations/20260728000000_grant_place_coords_select.sql \
        scripts/backfill_place_coords.py \
        scripts/tests/test_backfill_place_coords.py
git commit -m "feat(daily-story): daily_story_places 加經緯度欄位與 backfill 腳本"
```

- [ ] **Step 7: 交給人類執行一次性作業**

告訴使用者：這支 migration 與 backfill 需要他親自對正式 Supabase 執行（`supabase db push`，然後 `cd scripts && uv run python backfill_place_coords.py --dry-run` 確認輸出無誤後拿掉 `--dry-run` 再跑一次）。腳本印出的「需要人工補座標」清單也要他處理。**不要自己去碰正式資料庫。**

---

### Task 2: `DailyStory` 帶上經緯度

**Files:**
- Modify: `frontend/lib/features/daily_story/domain/models/daily_story.dart`
- Modify: `frontend/lib/features/daily_story/data/supabase_daily_story_repository.dart:15-16,63-89`
- Test: `frontend/test/features/daily_story/data/supabase_daily_story_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `latitude` / `longitude` 欄位。
- Produces: `DailyStory.latitude` / `DailyStory.longitude`（`double?`）。Task 9 的首頁靠它決定要不要把故事釘上地球儀。

- [ ] **Step 1: 寫失敗測試**

在 `frontend/test/features/daily_story/data/supabase_daily_story_repository_test.dart` 加入（若檔案不存在就建立，並補上 `import 'package:flutter_test/flutter_test.dart';` 與 repository 的 import）：

```dart
test(
  'given a row whose place join carries coordinates, '
  'when rowToStory parses it, '
  'then latitude and longitude are mapped',
  () {
    final story = SupabaseDailyStoryRepository.rowToStory({
      'publish_date': '2026-07-28',
      'language': 'zh-TW',
      'place_name': '聖伯多祿大殿',
      'place_location': '義大利羅馬',
      'era': '公元 1506-1626 年',
      'story': '內文',
      'image_url': null,
      'wikipedia_url': 'https://zh.wikipedia.org/wiki/聖伯多祿大殿',
      'daily_story_places': {'latitude': 41.9022, 'longitude': 12.4539},
    });

    expect(story.latitude, 41.9022);
    expect(story.longitude, 12.4539);
  },
);

test(
  'given a row with no place join, '
  'when rowToStory parses it, '
  'then latitude and longitude are null',
  () {
    final story = SupabaseDailyStoryRepository.rowToStory({
      'publish_date': '2026-07-28',
      'language': 'zh-TW',
      'place_name': '聖伯多祿大殿',
      'place_location': '義大利羅馬',
      'era': '公元 1506-1626 年',
      'story': '內文',
      'image_url': null,
      'wikipedia_url': 'https://zh.wikipedia.org/wiki/聖伯多祿大殿',
    });

    expect(story.latitude, isNull);
    expect(story.longitude, isNull);
  },
);
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/daily_story/data/supabase_daily_story_repository_test.dart`
Expected: 編譯失敗，`The getter 'latitude' isn't defined for the class 'DailyStory'`

- [ ] **Step 3: 加欄位**

`daily_story.dart`：在 `wikidataId` 欄位宣告後加上

```dart
  /// 景點的緯度，來自 `daily_story_places.latitude`。地球儀首頁用它決定
  /// 要不要把這篇故事釘上地球。舊資料尚未 backfill 時為 null。
  final double? latitude;

  /// 景點的經度，來自 `daily_story_places.longitude`。
  final double? longitude;
```

constructor 參數列在 `this.wikidataId,` 之後加 `this.latitude,` 與 `this.longitude,`；`props` 在 `wikidataId,` 之後加 `latitude,` 與 `longitude,`。

- [ ] **Step 4: 更新 repository**

`supabase_daily_story_repository.dart` 的 `_select` 改成：

```dart
  static const _select =
      '*, daily_story_places!left(card_location_en, card_city_ch, card_city_en, '
      'wikidata_id, latitude, longitude)';
```

`rowToStory` 在 `wikidataId: place?['wikidata_id'] as String?,` 之後加：

```dart
      latitude: (place?['latitude'] as num?)?.toDouble(),
      longitude: (place?['longitude'] as num?)?.toDouble(),
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/daily_story/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

- [ ] **Step 6: 提交**

```bash
git add frontend/lib/features/daily_story frontend/test/features/daily_story
git commit -m "feat(daily-story): DailyStory 帶上景點經緯度"
```

---

### Task 3: 世界陸地輪廓 asset 與解析

**Files:**
- Create: `frontend/tool/build_world_outline.py`
- Create: `frontend/assets/geo/world_land_110m.json`
- Create: `frontend/lib/features/home/domain/globe/world_outline.dart`
- Modify: `frontend/pubspec.yaml:151-159`
- Test: `frontend/test/features/home/domain/globe/world_outline_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces: `WorldOutline`，欄位 `List<List<LatLng>> rings`；靜態方法 `WorldOutline.parse(String json)` 與 `Future<WorldOutline> WorldOutline.load(AssetBundle bundle)`。Task 6 的 painter 消費它。

- [ ] **Step 1: 寫轉檔工具**

建立 `frontend/tool/build_world_outline.py`（比照既有的 `tool/build_map_style.py` 為一次性產生器）：

```python
"""把 Natural Earth 110m 陸地 GeoJSON 壓成 App 用的緊湊輪廓檔。

用法：
    curl -sL -o /tmp/ne110.geojson \\
      https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
    python3 tool/build_world_outline.py /tmp/ne110.geojson assets/geo/world_land_110m.json

輸出格式：{"rings": [[lng, lat, lng, lat, ...], ...]}
座標取到小數 2 位——地球儀直徑約 344px、可見半球涵蓋 180 度，一個像素
約 0.5 度，0.01 度遠在一像素之下，肉眼看不出差別。
"""

import json
import sys


def build(geojson: dict) -> dict:
    rings: list[list[float]] = []
    for feature in geojson["features"]:
        geometry = feature["geometry"]
        polygons = (
            [geometry["coordinates"]]
            if geometry["type"] == "Polygon"
            else geometry["coordinates"]
        )
        for polygon in polygons:
            for ring in polygon:
                flat: list[float] = []
                for lng, lat in ring:
                    flat.append(round(lng, 2))
                    flat.append(round(lat, 2))
                rings.append(flat)
    return {"rings": rings}


if __name__ == "__main__":
    source, target = sys.argv[1], sys.argv[2]
    with open(source, encoding="utf-8") as handle:
        data = json.load(handle)
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(build(data), handle, separators=(",", ":"))
    print(f"寫入 {target}：{len(build(data)['rings'])} 條環")
```

- [ ] **Step 2: 產生 asset 並登記**

```bash
cd frontend
mkdir -p assets/geo
curl -sL -o /tmp/ne110.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson
python3 tool/build_world_outline.py /tmp/ne110.geojson assets/geo/world_land_110m.json
```

預期輸出 128 條環（127 個 feature，其中歐亞大陸的 Polygon 多挖了一個裡海形
狀的內環，因為裡海是內陸水域）。`pubspec.yaml` 的 assets 清單在 `- assets/map/`
之後加：

```yaml
    # 由 tool/build_world_outline.py 從 Natural Earth 110m 產生，勿手改
    - assets/geo/
```

- [ ] **Step 3: 寫失敗測試**

建立 `frontend/test/features/home/domain/globe/world_outline_test.dart`：

```dart
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'given a compact rings payload, '
    'when parsing it, '
    'then each flat coordinate pair becomes a LatLng in lng/lat order',
    () {
      final outline = WorldOutline.parse(
        '{"rings":[[12.45,41.9,12.5,41.95,12.45,41.9]]}',
      );

      expect(outline.rings, hasLength(1));
      expect(outline.rings.single, hasLength(3));
      expect(outline.rings.single.first.latitude, 41.9);
      expect(outline.rings.single.first.longitude, 12.45);
    },
  );

  testWidgets(
    'given the bundled world outline asset, '
    'when loading it, '
    'then it yields the full Natural Earth 110m ring set',
    (tester) async {
      // WorldOutline.load 用 compute() 開真正的背景 isolate；testWidgets
      // 預設跑在 FakeAsync zone，等不到真實 isolate 的回應會卡死，所以要用
      // runAsync 讓這段跳出 FakeAsync、用真實事件迴圈執行。
      final outline = (await tester.runAsync(
        () => WorldOutline.load(rootBundle),
      ))!;

      // 127 個 feature ＋ 歐亞大陸裡海那一個內環，共 128 條環。
      expect(outline.rings, hasLength(128));
      expect(
        outline.rings.every((ring) => ring.length >= 4),
        isTrue,
        reason: '每條環至少要有 4 個點才畫得出多邊形',
      );
    },
  );
}
```

- [ ] **Step 4: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/world_outline_test.dart`
Expected: FAIL，`Target of URI doesn't exist: .../world_outline.dart`

- [ ] **Step 5: 實作**

建立 `frontend/lib/features/home/domain/globe/world_outline.dart`：

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// 地球儀要畫的陸地輪廓。
///
/// 資料由 `tool/build_world_outline.py` 從 Natural Earth 110m 產生，
/// 存成 `{"rings": [[lng, lat, lng, lat, ...], ...]}` 的緊湊格式——一條環
/// 一個扁平陣列，省掉每個點一組中括號的體積。
class WorldOutline {
  const WorldOutline(this.rings);

  /// 每條環是一個閉合多邊形的頂點序列。
  final List<List<LatLng>> rings;

  static const String assetPath = 'assets/geo/world_land_110m.json';

  static WorldOutline parse(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final rings = <List<LatLng>>[];
    for (final ring in decoded['rings'] as List) {
      final flat = (ring as List).cast<num>();
      final points = <LatLng>[];
      for (var i = 0; i + 1 < flat.length; i += 2) {
        points.add(LatLng(flat[i + 1].toDouble(), flat[i].toDouble()));
      }
      rings.add(points);
    }
    return WorldOutline(rings);
  }

  /// 從 asset bundle 載入。解析放在背景 isolate，避免擋住第一幀。
  static Future<WorldOutline> load(AssetBundle bundle) async {
    final source = await bundle.loadString(assetPath);
    return compute(parse, source);
  }
}
```

- [ ] **Step 6: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/world_outline_test.dart && fvm flutter analyze --fatal-infos`
Expected: 2 passed、analyze 零問題

- [ ] **Step 7: 提交**

```bash
git add frontend/tool/build_world_outline.py frontend/assets/geo \
        frontend/pubspec.yaml frontend/lib/features/home frontend/test/features/home
git commit -m "feat(home): 打包世界陸地輪廓 asset 與解析"
```

---

### Task 4: 正射投影與可見性

**Files:**
- Create: `frontend/lib/features/home/domain/globe/globe_rotation.dart`
- Create: `frontend/lib/features/home/domain/globe/orthographic_projection.dart`
- Test: `frontend/test/features/home/domain/globe/orthographic_projection_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces:
  - `GlobeRotation(double lambda, double phi)`，`LatLng get viewCenter`，`static GlobeRotation facing(LatLng point, {double tilt = 8})`，`GlobeRotation lerpTo(GlobeRotation other, double t)`，`GlobeRotation clampedPhi()`。
  - `OrthographicProjection({required GlobeRotation rotation, required Offset center, required double radius})`，方法 `Offset? project(LatLng)`、`bool isVisible(LatLng)`、`double angularDistanceTo(LatLng)`。
  - Task 5 在同一個 class 上加 `clipRing`。

- [ ] **Step 1: 寫失敗測試**

建立 `frontend/test/features/home/domain/globe/orthographic_projection_test.dart`：

```dart
import 'dart:ui';

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _center = Offset(100, 100);
const _radius = 100.0;

OrthographicProjection _projectionFacing(LatLng point) =>
    OrthographicProjection(
      rotation: GlobeRotation.facing(point, tilt: 0),
      center: _center,
      radius: _radius,
    );

void main() {
  test(
    'given a rotation facing a point, '
    'when projecting that point, '
    'then it lands on the canvas centre',
    () {
      final projection = _projectionFacing(const LatLng(41.9, 12.45));

      final offset = projection.project(const LatLng(41.9, 12.45));

      expect(offset, isNotNull);
      expect(offset!.dx, closeTo(_center.dx, 0.001));
      expect(offset.dy, closeTo(_center.dy, 0.001));
    },
  );

  test(
    'given a rotation facing the prime meridian on the equator, '
    'when projecting a point due north, '
    'then it lands above the centre on screen',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(45, 0))!;

      expect(offset.dx, closeTo(_center.dx, 0.001));
      expect(offset.dy, lessThan(_center.dy));
    },
  );

  test(
    'given a rotation facing the prime meridian on the equator, '
    'when projecting a point due east, '
    'then it lands to the right of the centre',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(0, 45))!;

      expect(offset.dx, greaterThan(_center.dx));
      expect(offset.dy, closeTo(_center.dy, 0.001));
    },
  );

  test(
    'given a point on the far hemisphere, '
    'when projecting it, '
    'then it is reported invisible and projects to null',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      expect(projection.isVisible(const LatLng(0, 179)), isFalse);
      expect(projection.project(const LatLng(0, 179)), isNull);
    },
  );

  test(
    'given a point exactly on the horizon, '
    'when projecting it, '
    'then it lands on the globe rim',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(0, 90))!;

      expect((offset - _center).distance, closeTo(_radius, 0.001));
    },
  );

  test(
    'given a rotation facing a point with a tilt, '
    'when reading the view centre, '
    'then the centre sits north of the focused point by the tilt',
    () {
      final rotation = GlobeRotation.facing(const LatLng(30, 120), tilt: 8);

      expect(rotation.viewCenter.latitude, closeTo(22, 0.001));
      expect(rotation.viewCenter.longitude, closeTo(120, 0.001));
    },
  );

  test(
    'given two rotations across the antimeridian, '
    'when interpolating halfway, '
    'then it takes the short way round',
    () {
      const from = GlobeRotation(170, 0);
      const to = GlobeRotation(-170, 0);

      final mid = from.lerpTo(to, 0.5);

      expect(mid.lambda, closeTo(180, 0.001));
    },
  );

  test(
    'given a rotation beyond the tilt limit, '
    'when clamping it, '
    'then phi is capped at 78 degrees',
    () {
      expect(const GlobeRotation(0, 120).clampedPhi().phi, 78);
      expect(const GlobeRotation(0, -120).clampedPhi().phi, -78);
    },
  );
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/orthographic_projection_test.dart`
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 實作 `GlobeRotation`**

建立 `frontend/lib/features/home/domain/globe/globe_rotation.dart`：

```dart
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 地球儀的旋轉角，沿用 d3.geoOrthographic 的慣例：
/// `rotate([lambda, phi])` 把球轉過去，視線中心因此落在 `(-phi, -lambda)`。
///
/// 只有兩個自由度——第三個滾轉角固定為 0，地球儀不會歪頭。
class GlobeRotation {
  const GlobeRotation(this.lambda, this.phi);

  /// 經度方向的旋轉（度）。可以超出 ±180，投影公式用的是差值。
  final double lambda;

  /// 緯度方向的旋轉（度）。
  final double phi;

  /// 目前正對鏡頭的那個點。
  LatLng get viewCenter => LatLng(-phi, -lambda);

  /// 轉到正對 [point]。[tilt] 把視線中心往北推幾度，讓 pin 落在球體偏上
  /// 的位置，底下才有空間放紙卡 chip（設計稿用 8 度）。
  static GlobeRotation facing(LatLng point, {double tilt = 8}) =>
      GlobeRotation(-point.longitude, -(point.latitude - tilt));

  /// 拖曳時把俯仰夾在 ±78 度，避免轉到極點附近整顆球看起來翻過去。
  GlobeRotation clampedPhi() =>
      GlobeRotation(lambda, phi.clamp(-78.0, 78.0).toDouble());

  /// 往 [other] 內插。經度走最短路徑，不會為了差 350 度而繞一大圈。
  GlobeRotation lerpTo(GlobeRotation other, double t) {
    var deltaLambda = other.lambda - lambda;
    deltaLambda = (deltaLambda % 360 + 540) % 360 - 180;
    return GlobeRotation(lambda + deltaLambda * t, phi + (other.phi - phi) * t);
  }

  double get lambdaRadians => lambda * math.pi / 180;

  double get phiRadians => phi * math.pi / 180;

  @override
  String toString() => 'GlobeRotation($lambda, $phi)';
}
```

- [ ] **Step 4: 實作 `OrthographicProjection`**

建立 `frontend/lib/features/home/domain/globe/orthographic_projection.dart`：

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';

/// 正射投影：把球面上的經緯度投到畫布座標，看起來就是從遠處看一顆球。
///
/// 公式是教科書版本（Snyder, Map Projections §20）：
///   x = R cos(φ) sin(λ − λ₀)
///   y = R [cos(φ₀) sin(φ) − sin(φ₀) cos(φ) cos(λ − λ₀)]
/// 其中 (φ₀, λ₀) 是視線中心。y 是「北為正」，畫布 y 軸向下，所以要反號。
class OrthographicProjection {
  const OrthographicProjection({
    required this.rotation,
    required this.center,
    required this.radius,
  });

  final GlobeRotation rotation;

  /// 球心在畫布上的位置。
  final Offset center;

  /// 球在畫布上的半徑（px）。
  final double radius;

  double _cosAngularDistance(LatLng point) {
    final viewCenter = rotation.viewCenter;
    final phi0 = viewCenter.latitude * math.pi / 180;
    final lambda0 = viewCenter.longitude * math.pi / 180;
    final phi = point.latitude * math.pi / 180;
    final lambda = point.longitude * math.pi / 180;
    return math.sin(phi0) * math.sin(phi) +
        math.cos(phi0) * math.cos(phi) * math.cos(lambda - lambda0);
  }

  /// [point] 是否落在面向鏡頭的半球上。剛好在地平線上算可見。
  bool isVisible(LatLng point) => _cosAngularDistance(point) >= 0;

  /// [point] 距離視線中心的大圓角距離（弧度，0 到 π）。
  double angularDistanceTo(LatLng point) =>
      math.acos(_cosAngularDistance(point).clamp(-1.0, 1.0));

  /// 投影到畫布座標。背面的點回傳 null。
  Offset? project(LatLng point) {
    if (!isVisible(point)) return null;
    return _projectUnchecked(point);
  }

  /// 不檢查可見性的投影。背面的點會鏡射到正面，只有在裁切演算法內部、
  /// 已經確認過可見性時才可以用。
  Offset _projectUnchecked(LatLng point) {
    final viewCenter = rotation.viewCenter;
    final phi0 = viewCenter.latitude * math.pi / 180;
    final lambda0 = viewCenter.longitude * math.pi / 180;
    final phi = point.latitude * math.pi / 180;
    final lambda = point.longitude * math.pi / 180;

    final x = math.cos(phi) * math.sin(lambda - lambda0);
    final y = math.cos(phi0) * math.sin(phi) -
        math.sin(phi0) * math.cos(phi) * math.cos(lambda - lambda0);
    return Offset(center.dx + radius * x, center.dy - radius * y);
  }
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/orthographic_projection_test.dart && fvm flutter analyze --fatal-infos`
Expected: 8 passed、analyze 零問題

- [ ] **Step 6: 提交**

```bash
git add frontend/lib/features/home/domain/globe frontend/test/features/home
git commit -m "feat(home): 地球儀正射投影與旋轉角"
```

---

### Task 5: 地平線裁切

多邊形跨過可見半球邊界時，不能只把背面的點丟掉——那會讓陸地缺一角或連出跨過球心的錯誤邊。這一步把環裁到地平線上，並沿著地平線圓弧把缺口補起來。

**Files:**
- Modify: `frontend/lib/features/home/domain/globe/orthographic_projection.dart`
- Test: `frontend/test/features/home/domain/globe/orthographic_clip_test.dart`

**Interfaces:**
- Consumes: Task 4 的 `OrthographicProjection`。
- Produces: `List<List<Offset>> clipRing(List<LatLng> ring)`——回傳零到多條已閉合的畫布多邊形。一條環跨過球緣兩次以上時會回傳多條。

**兩個維護上的關鍵事實（實作時實測確認）：**

1. **輪廓資料走 Shapefile 環繞慣例（外環順時針），與 RFC 7946 相反。**
   128 條環裡 126 條外環是順時針，唯一逆時針的是 52 點的裡海內環（洞）。
   裁切的補弧方向取自環自身的環繞方向，所以這個慣例不能在 Task 3 的解析
   端被「正規化」掉。
2. **Task 6 畫的時候，同一份輪廓的所有環、所有多邊形要加進同一個 `Path`。**
   裡海那個洞靠 `PathFillType.nonZero` 加上反向環繞挖出來；分成多個 Path
   各自填色就挖不出洞。

- [ ] **Step 1: 寫失敗測試**

建立 `frontend/test/features/home/domain/globe/orthographic_clip_test.dart`：

```dart
import 'dart:math' as math;

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _center = Offset(100, 100);
const _radius = 100.0;
const _discArea = math.pi * _radius * _radius;

OrthographicProjection _facing(LatLng point) => OrthographicProjection(
  rotation: GlobeRotation.facing(point, tilt: 0),
  center: _center,
  radius: _radius,
);

/// 一條沿著固定緯度繞行整圈的環，用來模擬南極洲那種包住極點的陸塊。
List<LatLng> _ringAtLatitude(double latitude) => [
  for (var lng = -180.0; lng <= 180.0; lng += 10) LatLng(latitude, lng),
];

/// 畫布座標的 shoelace 有號面積。正負代表環繞方向——洞環必須跟外環反號，
/// nonZero 填法才挖得出洞。
double _signedArea(List<Offset> ring) {
  var total = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    total += a.dx * b.dy - b.dx * a.dy;
  }
  return total / 2;
}

double _signedAreaOf(List<List<Offset>> rings) =>
    rings.fold<double>(0, (sum, ring) => sum + _signedArea(ring));

/// 射線法判斷點在不在多邊形內。
bool _contains(List<Offset> polygon, Offset point) {
  var inside = false;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    if ((a.dy > point.dy) != (b.dy > point.dy)) {
      final x = a.dx + (point.dy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx);
      if (x > point.dx) inside = !inside;
    }
  }
  return inside;
}

void main() {
  test(
    'given a ring wholly on the near hemisphere, '
    'when clipping it, '
    'then the projected vertices come back in the original order',
    () {
      // 這條不變量是裡海那個洞的命根子：完全可見的環走早退路徑，點序必須
      // 原封不動。一旦有人在那裡加了 sort、reversed、或換個起點，環繞方向
      // 就毀了，nonZero 會把洞填成陸地。斷言完整點序才擋得住。
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 0),
        const LatLng(10, 0),
        const LatLng(10, 10),
        const LatLng(0, 10),
      ];

      final clipped = projection.clipRing(ring);

      expect(clipped, hasLength(1));
      expect(clipped.single, [
        for (final point in ring) projection.project(point)!,
      ]);
    },
  );

  test(
    'given a ring wholly on the far hemisphere, '
    'when clipping it, '
    'then nothing is returned',
    () {
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 170),
        const LatLng(10, 170),
        const LatLng(10, 180),
        const LatLng(0, 180),
      ];

      expect(projection.clipRing(ring), isEmpty);
    },
  );

  test(
    'given a ring straddling the horizon, '
    'when clipping it, '
    'then the result stays inside the globe and touches the rim',
    () {
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 60),
        const LatLng(20, 60),
        const LatLng(20, 120),
        const LatLng(0, 120),
      ];

      final clipped = projection.clipRing(ring);

      expect(clipped, hasLength(1));
      final points = clipped.single;
      expect(
        points.every((p) => (p - _center).distance <= _radius + 0.01),
        isTrue,
        reason: '裁切後不該有任何點跑到球外',
      );
      expect(
        points.any((p) => ((p - _center).distance - _radius).abs() < 0.01),
        isTrue,
        reason: '跨過地平線的環一定有點落在球緣上',
      );
    },
  );

  test(
    'given a ring bounding the far polar cap, '
    'when clipping it, '
    'then the cap side of the rim is filled and the rest of the globe is not',
    () {
      // 視線中心在北緯 20 度，南緯 60 度那一圈只有靠近我們的一段可見。
      // 缺口要沿球緣補在極冠那一側；補錯邊會把整個北半球填成陸地。
      final projection = _facing(const LatLng(20, 0));

      final clipped = projection.clipRing(_ringAtLatitude(-60));

      expect(clipped, hasLength(1));
      final points = clipped.single;
      expect(
        points.every((p) => p.dy >= _center.dy),
        isTrue,
        reason: '填的是南極那一側，不該有任何點跑到球心以北',
      );
      expect(
        _contains(points, _center + const Offset(0, 99.3)),
        isTrue,
        reason: '南極那側緊貼球緣的一小條要被填起來',
      );
      expect(
        _contains(points, _center + const Offset(0, -99.3)),
        isFalse,
        reason: '北邊緊貼球緣處是海，不能被填',
      );
    },
  );

  test(
    'given a hole ring straddling the horizon, '
    'when clipping it, '
    'then it keeps the opposite winding to the same ring wound as land',
    () {
      // 裡海是歐亞大陸那條環裡的反向內環。它跨過球緣時若裁成「整個圓盤扣
      // 掉湖」，nonZero 疊起來會把整塊大陸消成空白。
      final projection = _facing(const LatLng(0, 0));
      const land = [
        LatLng(0, 60),
        LatLng(20, 60),
        LatLng(20, 120),
        LatLng(0, 120),
      ];
      final hole = land.reversed.toList();

      final landArea = _signedAreaOf(projection.clipRing(land));
      final holeArea = _signedAreaOf(projection.clipRing(hole));

      expect(landArea * holeArea, lessThan(0), reason: '兩者必須反號');
      expect(
        (landArea.abs() - holeArea.abs()).abs(),
        lessThan(0.01 * landArea.abs()),
        reason: '同一塊區域，面積大小應該一樣',
      );
      expect(
        holeArea.abs() / _discArea,
        lessThan(0.1),
        reason: '裁出來的該是湖本身，不是圓盤扣掉湖',
      );
    },
  );

  test(
    'given a ring whose visible part is split in two by a notch, '
    'when clipping it, '
    'then each run closes onto its own entry and two polygons come back',
    () {
      // 南緯 60 的緯線圈，在經度 ±5 之間往南凹到南緯 85。視線中心北緯 10
      // 度時，那個凹口正好落在可見範圍中間，把可見部分切成左右兩段 run。
      //
      // 正確的配對是「離開點沿球緣往前走，遇到的下一個進入點」——這裡兩段
      // run 各自接回自己的進入點，所以會回傳兩條多邊形。若改成照 run 在環
      // 上的先後順序頭尾相接，兩段會被串成一條、把整個圓盤填成陸地
      // （實測 polys=1、面積 100.99%）。
      //
      // 這個輸入是專為守住配對規則挑的：run 數為 2 但交點在球緣上不交錯，
      // 兩種配對規則才會給出不同答案。
      final projection = _facing(const LatLng(10, 0));
      final ring = <LatLng>[
        for (var lng = -180.0; lng <= -5.0; lng += 5) LatLng(-60, lng),
        const LatLng(-85, -5),
        const LatLng(-85, 5),
        for (var lng = 5.0; lng <= 180.0; lng += 5) LatLng(-60, lng),
      ];

      final clipped = projection.clipRing(ring);

      expect(
        clipped,
        hasLength(2),
        reason: '兩段 run 各自封閉，照環上順序接則只會得到一條',
      );
      expect(
        clipped.every(
          (poly) =>
              poly.every((p) => (p - _center).distance <= _radius + 0.01),
        ),
        isTrue,
        reason: '裁切後不該有任何點跑到球外',
      );
      expect(
        _signedAreaOf(clipped).abs() / _discArea,
        lessThan(0.1),
        reason: '可見的只有兩小片極冠，填色面積不該接近整個圓盤',
      );
    },
  );
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/orthographic_clip_test.dart`
Expected: FAIL，`The method 'clipRing' isn't defined`

- [ ] **Step 3: 實作 `clipRing`**

在 `orthographic_projection.dart` 的 class 內加上（只用 `dart:ui` 與
`dart:math`，不需要 `package:flutter/painting.dart`）：

```dart
  /// 把一條球面環裁切到可見半球，回傳可以直接填色的畫布多邊形。
  ///
  /// 作法是 Weiler–Atherton：沿著環走一圈，記下每次穿過地平線的交點，把連
  /// 續可見的一段收成一條「run」（從進入點走到離開點）。缺口沿著球緣圓弧
  /// 補——從一條 run 的離開點朝球緣自己的環繞方向走，走到下一個進入點為止。
  ///
  /// 兩件事不能便宜行事：
  ///
  /// 一是補的方向要看環自己怎麼繞（見 [_windingSign]），不能就近走短弧、
  /// 也不能從最後一段可見邊去猜。方向決定的是缺口補在球緣的哪一側，也就
  /// 是陸地補在極冠那側還是反過來填掉整片海。
  ///
  /// 二是配對不能照 run 在環上的先後順序接。一條環可能分成好幾段可見的
  /// run，離開點該接的是「沿球緣往前走遇到的下一個進入點」，不見得是下一
  /// 條 run 的開頭。接錯的話整個圓盤會被填成陸地——南極洲在視線中心北緯
  /// 5～15 度時就是這個情形。
  List<List<Offset>> clipRing(List<LatLng> ring) {
    if (ring.length < 3) return const [];

    final runs = <List<Offset>>[];
    List<Offset>? current;

    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      final aVisible = isVisible(a);
      final bVisible = isVisible(b);

      if (aVisible) {
        current ??= <Offset>[];
        current.add(_projectUnchecked(a));
      }
      if (aVisible != bVisible) {
        final crossing = _horizonCrossing(a, b);
        if (aVisible) {
          current!.add(crossing);
          runs.add(current);
          current = null;
        } else {
          current = <Offset>[crossing];
        }
      }
    }

    if (current != null) {
      if (runs.isEmpty) {
        runs.add(current);
      } else {
        // 環是閉合的，最後一段其實接在第一段前面。
        runs.first.insertAll(0, current);
      }
    }

    if (runs.isEmpty) return const [];
    // 整條環都看得見時原封不動回傳。輪廓資料靠環繞方向慣例搭配 nonZero
    // 填法挖洞（裡海是歐亞大陸那條環裡的一個反向內環），點序一旦被重排或
    // 反向，洞就會被填成陸地。沒有交點就沒得裁，直接原樣送回最安全。
    if (runs.length == 1 && ring.every(isVisible)) {
      return [runs.single];
    }

    // 走到這裡的每條 run 都是「進入點 → 離開點」，兩端都在球緣上。
    final sweepSign = _windingSign(ring);
    final entryAngles = [
      for (final run in runs) (run.first - center).direction,
    ];
    final visited = List<bool>.filled(runs.length, false);
    final polygons = <List<Offset>>[];

    for (var start = 0; start < runs.length; start++) {
      if (visited[start]) continue;
      final polygon = <Offset>[];
      var i = start;
      while (!visited[i]) {
        visited[i] = true;
        polygon.addAll(runs[i]);
        final next = _nextEntry(runs[i].last, entryAngles, sweepSign);
        polygon.addAll(_rimArc(runs[i].last, runs[next].first, sweepSign));
        i = next;
      }
      polygons.add(polygon);
    }
    return polygons;
  }

  /// 環的環繞方向：順時針（外環）回 +1，逆時針（洞環）回 -1。
  ///
  /// 用球面有號面積（Chamberlain–Duquette）而不是把經緯度當平面算：常數項
  /// 那個 2 讓包住極點的環（南極洲）也算得出來，Δλ 取最短差則讓跨換日線的
  /// 環不會爆掉。
  ///
  /// 補弧的方向必須跟著環自己的方向走。裁切算的是「環所圍的區域 ∩ 可見半
  /// 球」，而洞環圍的是湖的補集——方向若一律照外環來，裡海一跨過球緣就會
  /// 裁出「整個圓盤扣掉湖」，nonZero 疊起來剛好把整塊歐亞大陸消成空白。
  static double _windingSign(List<LatLng> ring) {
    var total = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      var deltaLambda = (b.longitude - a.longitude) * math.pi / 180;
      deltaLambda = (deltaLambda + 3 * math.pi) % (2 * math.pi) - math.pi;
      total +=
          deltaLambda *
          (2 +
              math.sin(a.latitude * math.pi / 180) +
              math.sin(b.latitude * math.pi / 180));
    }
    return total >= 0 ? 1.0 : -1.0;
  }

  /// 從球緣上的離開點 [exit] 出發，朝 [sweepSign] 的方向沿球緣走，遇到的
  /// 第一個進入點。
  ///
  /// 進出點沿著球緣必然交錯出現（封閉曲線每穿過球緣一次，圓周上的內外就
  /// 翻一次），所以這個「下一個」是唯一且成雙的，每條 run 恰好被接一次。
  int _nextEntry(Offset exit, List<double> entryAngles, double sweepSign) {
    final exitAngle = (exit - center).direction;
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i < entryAngles.length; i++) {
      final gap = ((entryAngles[i] - exitAngle) * sweepSign) % (2 * math.pi);
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }

  /// 在 [a] 與 [b]（一端可見、另一端不可見）之間用二分法找出地平線交點。
  ///
  /// 沒有解析解可用：可見性看的是與視線中心的大圓角距離，沿著大圓走時它
  /// 是單調變化的，所以二分法必然收斂，20 次就遠小於一個像素。
  Offset _horizonCrossing(LatLng a, LatLng b) {
    var lo = 0.0;
    var hi = 1.0;
    final startVisible = isVisible(a);
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      final point = _interpolate(a, b, mid);
      if (isVisible(point) == startVisible) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final crossing = _interpolate(a, b, (lo + hi) / 2);
    // 數值上可能差幾個 1e-6，直接投影後推回球緣，避免留下毛邊。
    final projected = _projectUnchecked(crossing) - center;
    return center + projected * (radius / projected.distance);
  }

  /// 沿著大圓在 [a] 與 [b] 之間取 [t] 比例的點（slerp）。
  ///
  /// 用 slerp 而不是對經緯度做線性內插：經緯度是球面的座標而非歐氏空間，
  /// 線性內插在高緯度或跨換日線時走的不是真正的最短路徑，找出來的交點會
  /// 偏離地平線。
  LatLng _interpolate(LatLng a, LatLng b, double t) {
    final av = _toVector(a);
    final bv = _toVector(b);
    final dot = (av[0] * bv[0] + av[1] * bv[1] + av[2] * bv[2]).clamp(
      -1.0,
      1.0,
    );
    final omega = math.acos(dot);
    if (omega < 1e-9) return a;
    final sinOmega = math.sin(omega);
    final ka = math.sin((1 - t) * omega) / sinOmega;
    final kb = math.sin(t * omega) / sinOmega;
    return _toLatLng([
      ka * av[0] + kb * bv[0],
      ka * av[1] + kb * bv[1],
      ka * av[2] + kb * bv[2],
    ]);
  }

  static List<double> _toVector(LatLng p) {
    final phi = p.latitude * math.pi / 180;
    final lambda = p.longitude * math.pi / 180;
    return [
      math.cos(phi) * math.cos(lambda),
      math.cos(phi) * math.sin(lambda),
      math.sin(phi),
    ];
  }

  static LatLng _toLatLng(List<double> v) {
    final length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    final x = v[0] / length, y = v[1] / length, z = v[2] / length;
    return LatLng(
      math.asin(z) * 180 / math.pi,
      math.atan2(y, x) * 180 / math.pi,
    );
  }

  /// 產生從 [from] 沿球緣走到 [to] 的圓弧取樣點，方向由 [sweepSign] 決定
  /// （+1 是角度遞增，畫布 y 軸向下，看起來就是順時針）。
  ///
  /// 方向來自環自己的環繞方向（見 [_windingSign]），不是從最後一段可見邊
  /// 去猜：邊在球緣附近幾乎是徑向的，切向分量小到正負號由捨入誤差決定，
  /// 猜出來的方向會隨著地球儀轉動忽正忽負。
  ///
  /// 弧長是方向決定出來的結果，不是另外挑的：往前走到下一個進入點為止，
  /// 該多長就多長，可能超過半圈。反過來說也不能改成「一律走短弧」——短弧
  /// 剛好對的時候是巧合，不是判準。（實務上真實陸塊圍的是角半徑遠小於
  /// 90 度的凸區域，與大圓相交的弧必然不超過半圈；南極洲走的就是短弧。）
  List<Offset> _rimArc(Offset from, Offset to, double sweepSign) {
    final fromAngle = (from - center).direction;
    final toAngle = (to - center).direction;
    final delta = ((toAngle - fromAngle) * sweepSign) % (2 * math.pi);

    const step = math.pi / 90; // 2 度取樣，肉眼看不出折線
    final count = math.max(1, (delta / step).ceil());
    return [
      for (var i = 1; i <= count; i++)
        center +
            Offset.fromDirection(
              fromAngle + sweepSign * delta * (i / count),
              radius,
            ),
    ];
  }
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/home/domain/globe/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

補弧方向的判準是**環自身的環繞方向**（`_windingSign`，球面有號面積），一
條環一個值。不要改用「最後一段可見邊與半徑的外積」那種局部判準：環離開
球緣時，邊的方向幾乎是純徑向的，切向分量趨近 0、正負號由捨入誤差決定，
方向會隨著地球儀轉動忽正忽負。實測澳洲一碰到球緣，填色面積就從 2.4% 跳
到 98.8%。

同理，run 的配對要沿球緣找「往前走遇到的下一個進入點」，不能照 run 在環
上的先後順序接。實測 114 個跨球緣的組合裡有 36 個分成兩段以上，接錯時南
極洲在視線中心北緯 5～15 度會把整個圓盤填成陸地。

- [ ] **Step 5: 提交**

```bash
git add frontend/lib/features/home/domain/globe frontend/test/features/home
git commit -m "feat(home): 地球儀地平線裁切"
```

---

### Task 6: 地球儀 widget

**Files:**
- Create: `frontend/lib/features/home/domain/models/globe_pin.dart`
- Create: `frontend/lib/features/home/presentation/widgets/globe_palette.dart`
- Create: `frontend/lib/features/home/presentation/widgets/globe_painter.dart`
- Create: `frontend/lib/features/home/presentation/widgets/globe_view.dart`
- Test: `frontend/test/features/home/presentation/widgets/globe_view_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `WorldOutline`、Task 4/5 的 `OrthographicProjection` 與 `GlobeRotation`。
- Produces:
  - `GlobePin({required String id, required LatLng coordinate, required String label})`。
  - `GlobeView({required WorldOutline outline, required List<GlobePin> pins, GlobePin? focus, double size = 344})`。Task 9 的首頁擺這顆 widget。

- [ ] **Step 1: 寫失敗測試**

建立 `frontend/test/features/home/presentation/widgets/globe_view_test.dart`：

```dart
import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_painter.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../../helpers/pump_app.dart';

final _outline = WorldOutline.parse(
  '{"rings":[[0,0,10,0,10,10,0,10]]}',
);

const _rome = GlobePin(
  id: 'stpeters',
  coordinate: LatLng(41.9, 12.45),
  label: '聖伯多祿大殿',
);
const _taichung = GlobePin(
  id: 'temple',
  coordinate: LatLng(24.06, 120.54),
  label: '四面佛寺',
);

Future<void> _givenGlobe(WidgetTester tester, {GlobePin? focus}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: Center(
        child: GlobeView(
          outline: _outline,
          pins: const [_rome, _taichung],
          focus: focus ?? _rome,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(initTestEnvironment);

  testWidgets(
    'given a focused pin, '
    'when the globe renders, '
    'then its label chip is shown',
    (tester) async {
      await _givenGlobe(tester);

      expect(find.text('聖伯多祿大殿'), findsOneWidget);
    },
  );

  testWidgets(
    'given a globe focused on one pin, '
    'when the focus changes to another pin, '
    'then the chip shows the new label once the flight settles',
    (tester) async {
      await _givenGlobe(tester);

      await _givenGlobe(tester, focus: _taichung);
      await tester.pumpAndSettle();

      expect(find.text('四面佛寺'), findsOneWidget);
      expect(find.text('聖伯多祿大殿'), findsNothing);

      // 光是看 chip 文字換了不夠：_FocusMarker 的 label 直接讀
      // widget.focus.label，跟飛行動畫轉到哪完全無關，就算動畫卡在半路也會
      // 顯示新標籤。這裡額外驗證 settle 後的旋轉真的落在台中正面，才是
      // 測試名稱說的「flight settles」。
      final rotation = (tester
              .widget<CustomPaint>(find.byKey(GlobeView.canvasKey))
              .painter!
          as GlobePainter)
          .rotation;
      final expected = GlobeRotation.facing(_taichung.coordinate);
      expect(rotation.lambda, closeTo(expected.lambda, 0.01));
      expect(rotation.phi, closeTo(expected.phi, 0.01));
    },
  );

  testWidgets(
    'given a rendered globe, '
    'when the user drags across it, '
    'then the painter repaints with a different rotation',
    (tester) async {
      await _givenGlobe(tester);
      double lambda() => (tester
              .widget<CustomPaint>(find.byKey(GlobeView.canvasKey))
              .painter!
          as GlobePainter)
          .rotation
          .lambda;
      final before = lambda();

      await tester.drag(find.byKey(GlobeView.canvasKey), const Offset(80, 0));
      await tester.pump();

      // 拖曳增益 0.32，80px 應該轉出約 25.6 度。
      expect(lambda() - before, closeTo(25.6, 0.01));
    },
  );
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/home/presentation/widgets/globe_view_test.dart`
Expected: FAIL，`Target of URI doesn't exist: .../globe_view.dart`

- [ ] **Step 3: 實作 `GlobePin` 與 `GlobePalette`**

`frontend/lib/features/home/domain/models/globe_pin.dart`：

```dart
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// 地球儀上的一個釘點。
class GlobePin extends Equatable {
  const GlobePin({
    required this.id,
    required this.coordinate,
    required this.label,
  });

  /// 對應的每日故事識別碼（用發布日期字串即可）。
  final String id;
  final LatLng coordinate;

  /// 顯示在點旁邊或紙卡 chip 上的地名。
  final String label;

  @override
  List<Object?> get props => [id, coordinate, label];
}
```

`frontend/lib/features/home/presentation/widgets/globe_palette.dart`：

```dart
import 'package:flutter/painting.dart';

/// 地球儀專屬的插畫色。
///
/// 這幾個顏色不在 `LorescapeTokens` 裡——它們只描述那顆手繪風的球（米白
/// 的海、抹茶綠的陸地），不是全 App 的語意色票，放進 tokens 反而會讓別的
/// 畫面誤用。
abstract final class GlobePalette {
  static const Color ocean = Color(0xFFFCF8ED);
  static const Color land = Color(0xFFCBD8A9);
  static const Color landStroke = Color.fromRGBO(101, 116, 74, 0.42);
  static const Color graticule = Color.fromRGBO(111, 124, 86, 0.17);
  static const Color rim = Color.fromRGBO(120, 106, 70, 0.3);
  static const Color shadeEdge = Color.fromRGBO(120, 106, 70, 0.22);
  static const Color pinDot = Color(0xFF5F7148);
  static const Color pinDotStroke = ocean;
  static const Color pinLabel = Color(0xFF6E6350);
}
```

- [ ] **Step 4: 實作 painter**

`frontend/lib/features/home/presentation/widgets/globe_painter.dart`：

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// latlong2 也匯出一個泛型 Path<T>，會跟 dart:ui 的 Path（畫布路徑）撞名，
// 這裡只需要經緯度型別，把它的 Path 隱藏掉。
import 'package:latlong2/latlong.dart' hide Path;

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_palette.dart';

/// 畫那顆手繪風地球：海、經緯網格、陸地、打光，最後是故事釘點。
///
/// 被選中的那個點不畫在這裡——它是疊在上層的 Flutter widget（水滴 pin 與
/// 紙卡 chip），這樣才能用 App 的字體與陰影，不必在 canvas 裡重刻一份。
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.outline,
    required this.pins,
    required this.rotation,
    required this.focusId,
  });

  final WorldOutline outline;
  final List<GlobePin> pins;
  final GlobeRotation rotation;
  final String? focusId;

  /// 網格線的間隔（度）。
  static const double _graticuleStep = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 3;
    final center = Offset(size.width / 2, size.height / 2);
    final projection = OrthographicProjection(
      rotation: rotation,
      center: center,
      radius: radius,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    canvas.drawCircle(center, radius, Paint()..color = GlobePalette.ocean);
    _paintGraticule(canvas, projection);
    _paintLand(canvas, projection);
    _paintShading(canvas, center, radius);

    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = GlobePalette.rim,
    );

    _paintPins(canvas, projection);
  }

  void _paintGraticule(Canvas canvas, OrthographicProjection projection) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = GlobePalette.graticule;

    for (var lat = -80.0; lat <= 80; lat += _graticuleStep) {
      _strokePath(
        canvas,
        projection,
        [for (var lng = -180.0; lng <= 180; lng += 5) LatLng(lat, lng)],
        paint,
      );
    }
    for (var lng = -180.0; lng < 180; lng += _graticuleStep) {
      _strokePath(
        canvas,
        projection,
        [for (var lat = -90.0; lat <= 90; lat += 5) LatLng(lat, lng)],
        paint,
      );
    }
  }

  /// 畫一條非閉合的線（網格用）。跨到背面就斷開重起，不要連過球心。
  void _strokePath(
    Canvas canvas,
    OrthographicProjection projection,
    List<LatLng> points,
    Paint paint,
  ) {
    final path = Path();
    var started = false;
    for (final point in points) {
      final offset = projection.project(point);
      if (offset == null) {
        started = false;
        continue;
      }
      if (started) {
        path.lineTo(offset.dx, offset.dy);
      } else {
        path.moveTo(offset.dx, offset.dy);
        started = true;
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintLand(Canvas canvas, OrthographicProjection projection) {
    final path = Path();
    for (final ring in outline.rings) {
      for (final clipped in projection.clipRing(ring)) {
        if (clipped.length < 3) continue;
        path.addPolygon(clipped, true);
      }
    }
    canvas.drawPath(path, Paint()..color = GlobePalette.land);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = GlobePalette.landStroke,
    );
  }

  /// 左上打光：中央偏亮、邊緣壓暗，讓平面的圓看起來像一顆球。
  void _paintShading(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - radius * 0.28, center.dy - radius * 0.4),
          radius,
          const [
            Color.fromRGBO(255, 255, 255, 0.5),
            Color.fromRGBO(255, 255, 255, 0),
            GlobePalette.shadeEdge,
          ],
          const [0, 0.55, 1],
        ),
    );
  }

  void _paintPins(Canvas canvas, OrthographicProjection projection) {
    final dot = Paint()..color = GlobePalette.pinDot;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = GlobePalette.pinDotStroke;

    for (final pin in pins) {
      if (pin.id == focusId) continue;
      // 太靠近球緣的點在視覺上已經貼在邊上，標籤會壓到球外，直接不畫。
      if (projection.angularDistanceTo(pin.coordinate) > 1.4) continue;
      final offset = projection.project(pin.coordinate);
      if (offset == null) continue;

      canvas.drawCircle(offset, 4.5, dot);
      canvas.drawCircle(offset, 4.5, ring);
      _paintLabel(canvas, projection, offset, pin.label);
    }
  }

  void _paintLabel(
    Canvas canvas,
    OrthographicProjection projection,
    Offset offset,
    String label,
  ) {
    final flipToLeft = offset.dx > projection.center.dx + projection.radius * 0.24;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: GlobePalette.pinLabel,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        flipToLeft ? offset.dx - 10 - painter.width : offset.dx + 10,
        offset.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(GlobePainter oldDelegate) =>
      oldDelegate.rotation.lambda != rotation.lambda ||
      oldDelegate.rotation.phi != rotation.phi ||
      oldDelegate.focusId != focusId ||
      oldDelegate.pins != pins ||
      oldDelegate.outline != outline;
}
```

- [ ] **Step 5: 實作 `GlobeView`**

`frontend/lib/features/home/presentation/widgets/globe_view.dart`：

```dart
import 'package:flutter/material.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_painter.dart';

/// 首頁那顆可拖曳的地球儀。
///
/// [focus] 換人時會用 950ms 的 easeOutCubic 轉過去；使用者拖曳期間動畫讓位
/// 給手指，放開後停在使用者轉到的角度，直到下一次 [focus] 變動。
class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.outline,
    required this.pins,
    required this.focus,
    this.size = 344,
  });

  final WorldOutline outline;

  /// 帶地名標籤的釘點（最近 7 篇）。
  final List<GlobePin> pins;

  /// 目前選中的故事地點。可能不在 [pins] 內（捲到更舊的卡片時）。
  final GlobePin? focus;

  final double size;

  /// 測試用來抓畫布與拖曳目標。
  static const Key canvasKey = Key('globe-canvas');

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView>
    with SingleTickerProviderStateMixin {
  static const Duration _flightDuration = Duration(milliseconds: 950);

  /// 拖曳位移換算成旋轉度數的比例，取自設計稿。
  static const double _dragGain = 0.32;

  late AnimationController _controller;
  late GlobeRotation _rotation;
  GlobeRotation _flightFrom = const GlobeRotation(0, 0);
  GlobeRotation _flightTo = const GlobeRotation(0, 0);

  @override
  void initState() {
    super.initState();
    _rotation = widget.focus == null
        ? const GlobeRotation(0, 0)
        : GlobeRotation.facing(widget.focus!.coordinate);
    _controller = AnimationController(vsync: this, duration: _flightDuration)
      ..addListener(_onFlightTick);
  }

  @override
  void didUpdateWidget(GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focus;
    if (focus == null || focus.id == oldWidget.focus?.id) return;
    _flightFrom = _rotation;
    _flightTo = GlobeRotation.facing(focus.coordinate);
    _controller.forward(from: 0);
  }

  void _onFlightTick() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    setState(() => _rotation = _flightFrom.lerpTo(_flightTo, t));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) => _controller.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation = GlobeRotation(
        _rotation.lambda + details.delta.dx * _dragGain,
        _rotation.phi - details.delta.dy * _dragGain,
      ).clampedPhi();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projection = OrthographicProjection(
      rotation: _rotation,
      center: Offset(widget.size / 2, widget.size / 2),
      radius: widget.size / 2 - 3,
    );
    final focus = widget.focus;
    final focusOffset = focus == null ? null : projection.project(focus.coordinate);
    final focusVisible = focus != null &&
        focusOffset != null &&
        projection.angularDistanceTo(focus.coordinate) < 1.32;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onPanStart: _onDragStart,
            onPanUpdate: _onDragUpdate,
            child: CustomPaint(
              key: GlobeView.canvasKey,
              size: Size.square(widget.size),
              painter: GlobePainter(
                outline: widget.outline,
                pins: widget.pins,
                rotation: _rotation,
                focusId: focus?.id,
              ),
            ),
          ),
          // focusOffset 在焦點剛切換、旋轉還沒轉到那一面時可能是 null（該點暫時
          // 在地球背面投影不出來）；這種情況先不畫標記，等飛行動畫轉過去再顯示。
          if (focus != null && focusOffset != null)
            Positioned(
              left: focusOffset.dx,
              top: focusOffset.dy,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: focusVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: _FocusMarker(label: focus.label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 選中地點的水滴 pin 與其上方的紙卡 chip。用 widget 而非 canvas，字體與
/// 陰影才會跟 App 其他地方一致。
class _FocusMarker extends StatelessWidget {
  const _FocusMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 外層 Positioned 把左上角放在投影點上。這裡水平往左推半個自身寬度做
    // 置中、垂直往上推一整個高度，讓水滴 pin 的尖端剛好落在座標上。寬度
    // 隨地名長短變動，所以用比例位移而不是寫死的 Offset。
    return FractionalTranslation(
      translation: const Offset(-0.5, -1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              border: Border.all(color: tokens.line),
              borderRadius: BorderRadius.circular(999),
              boxShadow: tokens.e2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.clay,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.96,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Transform.rotate(
            angle: -0.7853981634, // -45 度，讓方角朝下當作水滴尖端
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: tokens.clay,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                boxShadow: tokens.e1,
              ),
              child: Center(
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: tokens.paperRaised,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/home/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

- [ ] **Step 7: 提交**

```bash
git add frontend/lib/features/home frontend/test/features/home
git commit -m "feat(home): 地球儀 widget 與釘點繪製"
```

---

### Task 7: 搜尋建議 API

首頁搜尋 bar 要在打字時給即時建議。既有的 `PlacesRepository.searchPlaces` 會先跑 Wikidata SPARQL 找地標再撈 Wikipedia 條目，太重，不適合每 300ms 打一次。這裡加一支輕量的標題自動完成。

**Files:**
- Modify: `frontend/lib/features/explore/data/services/wikipedia_places_service.dart`
- Modify: `frontend/lib/features/explore/domain/repositories/places_repository.dart`
- Modify: `frontend/lib/features/explore/data/repositories/places_repository_impl.dart`
- Modify: `frontend/lib/features/explore/data/repositories/caching_places_repository.dart`
- Modify: `frontend/lib/features/explore/providers.dart`
- Modify: `frontend/test/fakes/fake_places_repository.dart`
- Test: `frontend/test/features/explore/data/services/wikipedia_places_service_suggest_test.dart`

**Interfaces:**
- Consumes: 無新依賴。
- Produces:
  - `Future<List<String>> WikipediaPlacesService.suggestTitles(String query, {required String wikiLang, int limit = 5})`
  - `Future<List<String>> PlacesRepository.suggestPlaceNames(String query, {required Language language})`
  - `placeSuggestionsProvider`：`FutureProvider.autoDispose.family<List<String>, String>`
  - `FakePlacesRepository.suggestions`（測試可設定的回傳值）與 `FakePlacesRepository.suggestCallCount`

- [ ] **Step 1: 寫失敗測試**

建立 `frontend/test/features/explore/data/services/wikipedia_places_service_suggest_test.dart`：

```dart
import 'dart:convert';

import 'package:context_app/features/explore/data/services/wikipedia_places_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'given an opensearch response, '
    'when suggesting titles, '
    'then the title array is returned in order',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'zh.wikipedia.org');
        expect(request.url.queryParameters['action'], 'opensearch');
        expect(request.url.queryParameters['search'], '京都');
        return http.Response(
          jsonEncode(['京都', ['京都市', '京都府', '京都御所'], [], []]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final titles = await WikipediaPlacesService(client: client)
          .suggestTitles('京都', wikiLang: 'zh');

      expect(titles, ['京都市', '京都府', '京都御所']);
    },
  );

  test(
    'given a non-200 response, '
    'when suggesting titles, '
    'then an empty list is returned instead of throwing',
    () async {
      final client = MockClient((_) async => http.Response('nope', 503));

      final titles = await WikipediaPlacesService(client: client)
          .suggestTitles('京都', wikiLang: 'zh');

      expect(titles, isEmpty);
    },
  );
}
```

先確認 `WikipediaPlacesService` 的 constructor 具名參數叫什麼（開檔案看），若不是 `client:` 就照實際簽章改測試的建構呼叫。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/explore/data/services/wikipedia_places_service_suggest_test.dart`
Expected: FAIL，`The method 'suggestTitles' isn't defined`

- [ ] **Step 3: 實作 service**

在 `wikipedia_places_service.dart` 的 `searchByText` 之後加：

```dart
  /// 標題自動完成，給首頁搜尋列的即時建議用。
  ///
  /// 用 `action=opensearch`——它只回標題陣列，比 `generator=search` 輕得多，
  /// 打字每一下都打得起。失敗時回空陣列而不是丟例外：建議清單消失比跳錯誤
  /// 對使用者干擾小。
  Future<List<String>> suggestTitles(
    String query, {
    required String wikiLang,
    int limit = 5,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'opensearch',
      'search': query,
      'limit': limit.toString(),
      'namespace': '0',
      'format': 'json',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.length < 2) return const [];
      final titles = decoded[1];
      if (titles is! List) return const [];
      return titles.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }
```

- [ ] **Step 4: 串到 repository 與 provider**

`places_repository.dart` 的 abstract class 加：

```dart
  /// 標題自動完成，給搜尋列的即時建議用。失敗時回空陣列。
  Future<List<String>> suggestPlaceNames(
    String query, {
    required Language language,
  });
```

`places_repository_impl.dart` 加實作（`_wikiLang` 是既有的私有方法）：

```dart
  @override
  Future<List<String>> suggestPlaceNames(
    String query, {
    required Language language,
  }) =>
      _service.suggestTitles(query, wikiLang: _wikiLang(language));
```

`caching_places_repository.dart` 加委派（建議不快取，字串每打一個字都不同，快取只會膨脹）：

```dart
  @override
  Future<List<String>> suggestPlaceNames(
    String query, {
    required Language language,
  }) =>
      _delegate.suggestPlaceNames(query, language: language);
```

`explore/providers.dart` 檔末加：

```dart
/// 搜尋列的即時建議。查詢字串當 family key，`autoDispose` 讓離開畫面後
/// 自動清掉——建議清單沒有跨畫面重用的價值。
final placeSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];
      final repository = ref.watch(placesRepositoryProvider);
      final language = ref.watch(currentLanguageProvider);
      return repository.suggestPlaceNames(trimmed, language: language);
    });
```

`test/fakes/fake_places_repository.dart` 加：

```dart
  /// 測試可預先設定的建議清單。
  List<String> suggestions = const [];

  /// `suggestPlaceNames` 被呼叫過幾次，用來驗證 debounce。
  int suggestCallCount = 0;

  @override
  Future<List<String>> suggestPlaceNames(
    String query, {
    required Language language,
  }) async {
    suggestCallCount++;
    return suggestions;
  }
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/explore/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

- [ ] **Step 6: 提交**

```bash
git add frontend/lib/features/explore frontend/test/features/explore frontend/test/fakes
git commit -m "feat(explore): 加上輕量的地點名稱自動完成"
```

---

### Task 8: 探索頁接受初始查詢並加地球儀返回鈕

**Files:**
- Modify: `frontend/lib/features/explore/presentation/screens/explore_screen.dart:23-40,616-660`
- Modify: `frontend/assets/translations/zh-TW.json`、`frontend/assets/translations/en.json`
- Test: `frontend/test/features/explore/presentation/screens/explore_screen_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces: `ExploreScreen({Key? key, String? initialQuery})`；畫面上多一顆 `Key('explore-globe-back')` 的返回鈕。Task 9 的路由用這兩者。

- [ ] **Step 1: 寫失敗測試**

在既有的 `explore_screen_test.dart` 加（沿用該檔已有的 fake 與 override 寫法；若檔案不存在則新建，並比照 `test/features/explore/` 內其他測試的 setup）：

```dart
testWidgets(
  'given an initial query, '
  'when the explore screen loads, '
  'then the places repository is searched with that query',
  (tester) async {
    final places = FakePlacesRepository();

    await pumpScreen(
      tester,
      child: const ExploreScreen(initialQuery: '京都'),
      overrides: [placesRepositoryProvider.overrideWithValue(places)],
    );
    await tester.pumpAndSettle();

    expect(places.lastSearchQuery, '京都');
  },
);

testWidgets(
  'given the explore screen pushed on top of home, '
  'when the user taps the globe button, '
  'then it pops back to the globe home',
  (tester) async {
    await pumpRouterApp(
      tester,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(key: Key('home-screen')),
        ),
        GoRoute(path: '/map', builder: (_, __) => const ExploreScreen()),
      ],
      overrides: [
        placesRepositoryProvider.overrideWithValue(FakePlacesRepository()),
      ],
    );
    // 從 / push 到 /map 才有東西可以 pop。
    final context = tester.element(find.byKey(const Key('home-screen')));
    GoRouter.of(context).push('/map');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore-globe-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  },
);
```

若 `FakePlacesRepository` 還沒有 `lastSearchQuery`，在 fake 的 `searchPlaces` 內加一個 `String? lastSearchQuery;` 欄位並賦值。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/explore/presentation/screens/explore_screen_test.dart`
Expected: FAIL，`No named parameter with the name 'initialQuery'`

- [ ] **Step 3: 加 `initialQuery`**

`ExploreScreen` 改成：

```dart
class ExploreScreen extends ConsumerStatefulWidget {
  /// 從首頁搜尋建議進來時帶的關鍵字。null 表示走預設的附近景點模式。
  final String? initialQuery;

  const ExploreScreen({super.key, this.initialQuery});
  ...
}
```

`_ExploreScreenState` 加：

```dart
  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery;
    if (query == null || query.isEmpty) return;
    _searchController.text = query;
    // build 期間不能改 provider，等第一幀畫完再送出搜尋。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = query;
      ref.read(placesControllerProvider.notifier).search(query);
    });
  }
```

- [ ] **Step 4: 加地球儀返回鈕**

`_MapTopOverlay` 加一個 `required VoidCallback onBack` 參數，並在 `Masthead` 的 `actions` 那個 `Row` 最前面插入：

```dart
                      _CircleButton(
                        key: const Key('explore-globe-back'),
                        icon: Icons.public,
                        tooltip: 'explore.back_to_globe'.tr(),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
```

`_CircleButton` 已存在於同檔（第 263 行起）；比照 `_FilterButton` / `_RefreshButton` 的用法傳參數，若 `_CircleButton` 沒有 `tooltip` 參數就改用 `Semantics(label: ...)` 包起來。`ExploreScreen.build` 傳 `onBack: () => context.pop()`（檔案已 import go_router）。

- [ ] **Step 5: 加 i18n key**

`zh-TW.json` 的 `explore` 物件加 `"back_to_globe": "回到地球儀"`；`en.json` 加 `"back_to_globe": "Back to globe"`。

- [ ] **Step 6: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/explore/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

- [ ] **Step 7: 提交**

```bash
git add frontend/lib/features/explore frontend/test frontend/assets/translations
git commit -m "feat(explore): 支援初始查詢與回到地球儀"
```

---

### Task 9: 地球儀首頁

**Files:**
- Create: `frontend/lib/features/home/providers.dart`
- Create: `frontend/lib/features/home/presentation/widgets/home_top_bar.dart`
- Create: `frontend/lib/features/home/presentation/widgets/story_rail.dart`
- Create: `frontend/lib/features/home/presentation/screens/globe_home_screen.dart`
- Modify: `frontend/assets/translations/zh-TW.json`、`en.json`
- Test: `frontend/test/features/home/presentation/screens/globe_home_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `DailyStory.latitude/longitude`、Task 3 的 `WorldOutline`、Task 6 的 `GlobeView` / `GlobePin`、Task 7 的 `placeSuggestionsProvider`。
- Produces: `GlobeHomeScreen`（`ConsumerStatefulWidget`，無參數）、`homeStoriesProvider`（`FutureProvider<List<DailyStory>>`）、`worldOutlineProvider`（`FutureProvider<WorldOutline>`）。Task 10 的路由掛這個畫面。

- [ ] **Step 1: 加 i18n key**

`zh-TW.json` 頂層加：

```json
  "home": {
    "eyebrow": "每日故事 · DAILY LORE",
    "brand": "Lorescape",
    "search_hint": "搜尋地點、城市或地標……",
    "search_clear": "清除",
    "locate": "定位",
    "deck_label": "每日故事 · ANNO MMXXVI",
    "badge_latest": "最新",
    "empty": "還沒有故事",
    "open_journey": "歷程書架",
    "open_settings": "設定"
  },
```

`en.json` 頂層加：

```json
  "home": {
    "eyebrow": "DAILY LORE",
    "brand": "Lorescape",
    "search_hint": "Search a place, city or landmark…",
    "search_clear": "Clear",
    "locate": "Nearby",
    "deck_label": "DAILY LORE · ANNO MMXXVI",
    "badge_latest": "Latest",
    "empty": "No stories yet",
    "open_journey": "Journey shelf",
    "open_settings": "Settings"
  },
```

- [ ] **Step 2: 寫失敗測試**

建立 `frontend/test/features/home/presentation/screens/globe_home_screen_test.dart`：

```dart
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/home/presentation/screens/globe_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_places_repository.dart';
import '../../../../fakes/in_memory_daily_story_repository.dart';
import '../../../../helpers/pump_app.dart';

DailyStory _story({
  required String date,
  required String place,
  double? latitude,
  double? longitude,
}) => DailyStory(
  publishDate: DateTime.parse(date),
  language: 'zh-TW',
  placeName: place,
  placeLocation: '某地',
  era: '某年',
  story: '內文',
  imageUrl: null,
  wikipediaUrl: 'https://zh.wikipedia.org/wiki/$place',
  latitude: latitude,
  longitude: longitude,
);

late InMemoryDailyStoryRepository _stories;
late FakePlacesRepository _places;

Future<void> _givenHome(
  WidgetTester tester, {
  required List<Object?> pushed,
}) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const GlobeHomeScreen()),
      GoRoute(
        path: '/map',
        builder: (_, state) {
          pushed.add('/map?q=${state.uri.queryParameters['q'] ?? ''}');
          return const Scaffold(key: Key('map-screen'));
        },
      ),
      GoRoute(
        path: '/journey',
        builder: (_, __) {
          pushed.add('/journey');
          return const Scaffold(key: Key('journey-screen'));
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) {
          pushed.add('/settings');
          return const Scaffold(key: Key('settings-screen'));
        },
      ),
      GoRoute(
        path: '/daily-story/detail',
        builder: (_, state) {
          pushed.add(state.extra);
          return const Scaffold(key: Key('detail-screen'));
        },
      ),
    ],
    overrides: [
      dailyStoryRepositoryProvider.overrideWithValue(_stories),
      placesRepositoryProvider.overrideWithValue(_places),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnvironment);

  setUp(() {
    _stories = InMemoryDailyStoryRepository()
      ..seed([
        _story(
          date: '2026-07-28',
          place: '聖伯多祿大殿',
          latitude: 41.9,
          longitude: 12.45,
        ),
        _story(
          date: '2026-07-27',
          place: '四面佛寺',
          latitude: 24.06,
          longitude: 120.54,
        ),
        _story(date: '2026-07-26', place: '沒有座標的地方'),
      ]);
    _places = FakePlacesRepository();
  });

  testWidgets(
    'given seeded daily stories, '
    'when the globe home loads, '
    'then every story appears in the rail and the newest one carries the badge',
    (tester) async {
      await _givenHome(tester, pushed: []);

      expect(find.text('聖伯多祿大殿'), findsWidgets);
      expect(find.text('四面佛寺'), findsOneWidget);
      expect(find.text('沒有座標的地方'), findsOneWidget);
      expect(find.text('home.badge_latest'), findsOneWidget);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the selected story card, '
    'then the daily story detail is pushed with that story',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('story-card-2026-07-28')));
      await tester.pumpAndSettle();

      expect(pushed.single, isA<DailyStory>());
      expect((pushed.single as DailyStory).placeName, '聖伯多祿大殿');
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the locate button, '
    'then the map opens with no query',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-locate')));
      await tester.pumpAndSettle();

      expect(pushed, ['/map?q=']);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the shelf button, '
    'then the journey screen opens',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-open-journey')));
      await tester.pumpAndSettle();

      expect(pushed, ['/journey']);
    },
  );

  testWidgets(
    'given the globe home, '
    'when the user taps the settings button, '
    'then the settings screen opens',
    (tester) async {
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.tap(find.byKey(const Key('home-open-settings')));
      await tester.pumpAndSettle();

      expect(pushed, ['/settings']);
    },
  );

  testWidgets(
    'given suggestions from the places repository, '
    'when the user types and waits out the debounce, '
    'then one request is made and tapping a suggestion opens the map with it',
    (tester) async {
      _places.suggestions = const ['京都市', '京都御所'];
      final pushed = <Object?>[];
      await _givenHome(tester, pushed: pushed);

      await tester.enterText(find.byKey(const Key('home-search')), '京');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('home-search')), '京都');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_places.suggestCallCount, 1, reason: 'debounce 應該吃掉第一次輸入');
      expect(find.text('京都市'), findsOneWidget);

      await tester.tap(find.text('京都市'));
      await tester.pumpAndSettle();

      expect(pushed, ['/map?q=京都市']);
    },
  );
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/home/presentation/screens/globe_home_screen_test.dart`
Expected: FAIL，`Target of URI doesn't exist: .../globe_home_screen.dart`

- [ ] **Step 4: 寫 providers**

建立 `frontend/lib/features/home/providers.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';

/// 首頁卡片列要顯示的故事：最新一篇在前，接著最多 30 篇歷史。
final homeStoriesProvider = FutureProvider<List<DailyStory>>((ref) async {
  final latest = await ref.watch(latestDailyStoryProvider.future);
  final history = await ref.watch(dailyStoryHistoryProvider.future);
  return [if (latest != null) latest, ...history];
});

/// 地球儀的世界輪廓。只解析一次，之後所有畫面共用。
final worldOutlineProvider = FutureProvider<WorldOutline>(
  (ref) => WorldOutline.load(rootBundle),
);
```

- [ ] **Step 5: 寫 `HomeTopBar`**

建立 `frontend/lib/features/home/presentation/widgets/home_top_bar.dart`：

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/explore/providers.dart';

/// 首頁頂部：眼眉字＋字標＋歷程/設定兩顆 icon，底下是搜尋列與建議清單。
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({
    super.key,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onSuggestionTap,
    required this.onOpenJourney,
    required this.onOpenSettings,
  });

  final TextEditingController controller;

  /// 已經過 debounce 的查詢字串；空字串代表不顯示建議。
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onOpenJourney;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final suggestions = query.isEmpty
        ? const AsyncValue<List<String>>.data([])
        : ref.watch(placeSuggestionsProvider(query));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'home.eyebrow'.tr(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.3,
                        color: tokens.clay,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'home.brand'.tr(),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 27,
                        height: 1,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _RaisedIconButton(
                key: const Key('home-open-journey'),
                icon: Icons.menu_book_outlined,
                label: 'home.open_journey'.tr(),
                onPressed: onOpenJourney,
              ),
              const SizedBox(width: 8),
              _RaisedIconButton(
                key: const Key('home-open-settings'),
                icon: Icons.settings_outlined,
                label: 'home.open_settings'.tr(),
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              borderRadius: BorderRadius.circular(tokens.rLg),
              boxShadow: tokens.e2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: tokens.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('home-search'),
                    controller: controller,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'home.search_hint'.tr(),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    key: const Key('home-search-clear'),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'home.search_clear'.tr(),
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                  ),
              ],
            ),
          ),
          suggestions.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _SuggestionList(
                      items: items,
                      onTap: onSuggestionTap,
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RaisedIconButton extends StatelessWidget {
  const _RaisedIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tokens.paperRaised,
            shape: BoxShape.circle,
            boxShadow: tokens.e1,
          ),
          child: Icon(icon, size: 21, color: tokens.ink2),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.paperRaised,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.rLg),
        boxShadow: tokens.e3,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) Divider(height: 1, color: tokens.line),
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: tokens.clayTint,
                child: Icon(
                  Icons.place_outlined,
                  size: 17,
                  color: tokens.clayDeep,
                ),
              ),
              title: Text(item),
              trailing: Icon(Icons.chevron_right, color: tokens.ink3),
              onTap: () => onTap(item),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 寫 `StoryRail`**

建立 `frontend/lib/features/home/presentation/widgets/story_rail.dart`：

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';

/// 底部的每日故事橫向卡片列。
///
/// 捲動時回報目前置中的索引，首頁拿它去轉地球儀；點選中的那張才進故事，
/// 點旁邊的卡片只是把它捲到中間（跟設計稿一致，避免誤觸）。
class StoryRail extends StatefulWidget {
  const StoryRail({
    super.key,
    required this.stories,
    required this.activeIndex,
    required this.onActiveChanged,
    required this.onOpen,
  });

  final List<DailyStory> stories;
  final int activeIndex;
  final ValueChanged<int> onActiveChanged;
  final ValueChanged<DailyStory> onOpen;

  /// 卡片寬度＋間距，用來換算捲動位置。
  static const double stride = 324;

  @override
  State<StoryRail> createState() => _StoryRailState();
}

class _StoryRailState extends State<StoryRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    final index = (notification.metrics.pixels / StoryRail.stride)
        .round()
        .clamp(0, widget.stories.length - 1);
    if (index != widget.activeIndex) widget.onActiveChanged(index);
    return false;
  }

  void _onCardTap(int index) {
    if (index == widget.activeIndex) {
      widget.onOpen(widget.stories[index]);
      return;
    }
    _controller.animateTo(
      index * StoryRail.stride,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (widget.stories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('home.empty'.tr(), textAlign: TextAlign.center),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(
                'home.deck_label'.tr(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: tokens.clay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: tokens.line)),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.stories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _StoryCard(
                story: widget.stories[index],
                isActive: index == widget.activeIndex,
                isLatest: index == 0,
                onTap: () => _onCardTap(index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.isActive,
    required this.isLatest,
    required this.onTap,
  });

  final DailyStory story;
  final bool isActive;
  final bool isLatest;
  final VoidCallback onTap;

  String get _dateKey =>
      '${story.publishDate.year.toString().padLeft(4, '0')}-'
      '${story.publishDate.month.toString().padLeft(2, '0')}-'
      '${story.publishDate.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      key: Key('story-card-$_dateKey'),
      onTap: onTap,
      child: Container(
        width: 312,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.paperRaised,
          border: Border.all(color: isActive ? tokens.clay : tokens.line),
          borderRadius: BorderRadius.circular(tokens.rLg),
          boxShadow: isActive ? tokens.e2 : tokens.e1,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.rMd),
              child: SizedBox(
                width: 78,
                height: 78,
                child: story.imageUrl == null
                    ? ColoredBox(color: tokens.paperSunk)
                    : CachedNetworkImage(
                        imageUrl: story.imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLatest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.clay,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'home.badge_latest'.tr(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: tokens.paperRaised,
                        ),
                      ),
                    )
                  else
                    Text(
                      _dateKey,
                      style: TextStyle(fontSize: 11, color: tokens.ink3),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    story.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story.placeLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: tokens.ink3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.ink3),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: 寫 `GlobeHomeScreen`**

建立 `frontend/lib/features/home/presentation/screens/globe_home_screen.dart`：

```dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:context_app/features/home/presentation/widgets/home_top_bar.dart';
import 'package:context_app/features/home/presentation/widgets/story_rail.dart';
import 'package:context_app/features/home/providers.dart';

/// 首頁：一顆釘著每日故事地點的地球儀，底下是故事卡片列。
///
/// 進入 `/map` 時，這一頁由 `secondaryAnimation` 驅動地球儀放大淡出、卡片
/// 列下滑，跟地圖的淡入接在一起（設計稿的 zoom-into-map）。
class GlobeHomeScreen extends ConsumerStatefulWidget {
  const GlobeHomeScreen({super.key});

  /// 地球儀上最多釘幾篇故事。更舊的故事只有被選中時才會出現那顆大 pin。
  static const int pinnedStoryCount = 7;

  @override
  ConsumerState<GlobeHomeScreen> createState() => _GlobeHomeScreenState();
}

class _GlobeHomeScreenState extends ConsumerState<GlobeHomeScreen> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  int _activeIndex = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
    // clear 按鈕的顯示與否要立刻反應。
    setState(() {});
  }

  void _openMap({String? query}) {
    final suffix = (query == null || query.isEmpty)
        ? ''
        : '?q=${Uri.encodeQueryComponent(query)}';
    context.push('/map$suffix');
  }

  GlobePin? _pinFor(DailyStory story) {
    final lat = story.latitude;
    final lng = story.longitude;
    if (lat == null || lng == null) return null;
    return GlobePin(
      id: story.publishDate.toIso8601String(),
      coordinate: LatLng(lat, lng),
      label: story.placeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stories = ref.watch(homeStoriesProvider).valueOrNull ?? const [];
    final outline = ref.watch(worldOutlineProvider).valueOrNull;

    final pins = <GlobePin>[
      for (final story in stories.take(GlobeHomeScreen.pinnedStoryCount))
        if (_pinFor(story) case final pin?) pin,
    ];
    final active = _activeIndex < stories.length
        ? _pinFor(stories[_activeIndex])
        : null;

    final secondary =
        ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    final zoom = CurvedAnimation(
      parent: secondary,
      curve: const Cubic(0.55, 0, 0.85, 0.36),
    );

    return Scaffold(
      backgroundColor: tokens.paper,
      body: AnimatedBuilder(
        animation: zoom,
        builder: (context, _) {
          final t = zoom.value;
          return Stack(
            children: [
              if (outline != null)
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(
                        scale: 1 + 3.8 * t,
                        child: GlobeView(
                          outline: outline,
                          pins: pins,
                          focus: active,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 1 - t,
                  child: HomeTopBar(
                    controller: _searchController,
                    query: _query,
                    onQueryChanged: _onQueryChanged,
                    onSuggestionTap: (value) {
                      _searchController.clear();
                      setState(() => _query = '');
                      _openMap(query: value);
                    },
                    onOpenJourney: () => context.push('/journey'),
                    onOpenSettings: () => context.push('/settings'),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 176,
                child: Opacity(
                  opacity: 1 - t,
                  child: _LocateButton(onPressed: () => _openMap()),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 4,
                child: FractionalTranslation(
                  translation: Offset(0, 1.2 * t),
                  child: Opacity(
                    opacity: 1 - t,
                    child: StoryRail(
                      stories: stories,
                      activeIndex: _activeIndex,
                      onActiveChanged: (index) =>
                          setState(() => _activeIndex = index),
                      onOpen: (story) =>
                          context.push('/daily-story/detail', extra: story),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: 'home.locate'.tr(),
      child: InkResponse(
        key: const Key('home-locate'),
        onTap: onPressed,
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: tokens.clay,
            borderRadius: BorderRadius.circular(999),
            boxShadow: tokens.e2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, size: 22, color: tokens.paperRaised),
              const SizedBox(height: 3),
              Text(
                'home.locate'.tr(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.paperRaised,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/home/ && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

若「點卡片開故事」那題失敗且訊息是找不到 `story-card-2026-07-28`，先確認 `pumpRouterApp` 的預設 800×600 測試視窗有沒有把 rail 擠出畫面——需要的話在測試中用 `tester.view.physicalSize` 調高，不要改 widget 的版面。

- [ ] **Step 9: 提交**

```bash
git add frontend/lib/features/home frontend/test/features/home frontend/assets/translations
git commit -m "feat(home): 地球儀首頁與每日故事卡片列"
```

---

### Task 10: 扁平路由與 zoom 轉場

**Files:**
- Modify: `frontend/lib/app/config/router_config.dart:58-85`
- Modify: `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart:66`
- Delete: `frontend/lib/app/shell/main_screen.dart`
- Delete: `frontend/lib/features/daily_story/presentation/screens/story_list_screen.dart`
- Delete: `frontend/test/app/shell/main_screen_test.dart`
- Delete: `frontend/test/features/daily_story/presentation/screens/story_list_screen_test.dart`
- Modify: `frontend/test/features/daily_story/integration/daily_story_localized_flow_test.dart`
- Modify: `frontend/test/features/trip/presentation/screens/trip_detail_screen_test.dart:175`
- Test: `frontend/test/app/config/router_config_test.dart`

**Interfaces:**
- Consumes: Task 8 的 `ExploreScreen({String? initialQuery})`、Task 9 的 `GlobeHomeScreen`。
- Produces: 路由名稱 `home` / `map` / `journey` / `settings`，`/map` 接 `?q=` 查詢參數。

- [ ] **Step 1: 寫失敗測試**

在 `frontend/test/app/config/router_config_test.dart` 加（若檔案不存在就建立，import `package:context_app/app/config/router_config.dart`、`package:flutter_riverpod/flutter_riverpod.dart`、`package:go_router/go_router.dart` 與 `package:flutter_test/flutter_test.dart`）：

```dart
test(
  'given the app router, '
  'when listing its top-level routes, '
  'then the flat globe-home layout is in place',
  () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final paths = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toList();

    expect(paths, containsAll(['/', '/map', '/journey', '/settings']));
  },
);
```

`routerProvider` 定義在 `router_config.dart` 檔末。若這個測試因為 Supabase / Firebase 尚未初始化而在建 router 時就爆掉，改成直接讀 `RouterConfig.createRouter` 需要的 `Ref` 太麻煩——那就把這題降級成「`grep` 不到 `MainScreen`」的結構測試，改用 Task 9 與 Task 11 已經有的導覽 widget test 來覆蓋實際跳轉。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/app/config/router_config_test.dart`
Expected: FAIL，`/map` 不在清單中

- [ ] **Step 3: 改路由**

`router_config.dart` 把 `/` 那一段（第 64–85 行）整段換成：

```dart
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const GlobeHomeScreen(),
        ),
        GoRoute(
          path: '/map',
          name: 'map',
          // 自訂轉場：首頁那一頁會讀 secondaryAnimation 把地球儀放大淡出，
          // 這裡只負責讓地圖淡入，兩段動畫共用同一個 640ms 時長才接得起來。
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 640),
            reverseTransitionDuration: const Duration(milliseconds: 640),
            child: ExploreScreen(
              initialQuery: state.uri.queryParameters['q'],
            ),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/journey',
          name: 'journey',
          builder: (context, state) => const JourneyScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
```

import 換掉：移除 `main_screen.dart`，加入 `globe_home_screen.dart`、`explore_screen.dart`、`journey_screen.dart`、`settings_screen.dart`。

- [ ] **Step 4: 刪掉舊畫面與舊測試**

```bash
cd frontend
git rm lib/app/shell/main_screen.dart \
       lib/features/daily_story/presentation/screens/story_list_screen.dart \
       test/app/shell/main_screen_test.dart \
       test/features/daily_story/presentation/screens/story_list_screen_test.dart
```

`trip_empty_state.dart` 第 66 行 `context.go('/?tab=explore')` 改成 `context.go('/map')`；`trip_detail_screen_test.dart` 第 175 行的期望值 `'/?tab=explore'` 一併改成 `'/map'`。

`daily_story_localized_flow_test.dart` 原本掛 `StoryListScreen`，改掛 `GlobeHomeScreen`，並確認它斷言的是故事文字而非畫面類別名稱；若該測試只是在驗證語言切換後故事跟著換，把 `pumpScreen(child: const StoryListScreen())` 換成 `pumpRouterApp(routes: [GoRoute(path: '/', builder: (_, __) => const GlobeHomeScreen())])` 即可。

- [ ] **Step 5: 跑全部測試**

Run: `cd frontend && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS（含 `test/architecture/dependency_rules_test.dart`）、analyze 零問題

依賴守門測試若對 `router_config.dart` 抱怨，確認新 import 都在 `_appCompositionRoots` 允許的檔案內——`router_config.dart` 本來就在清單上，不要去改那份清單。

- [ ] **Step 6: 提交**

```bash
git add -A frontend
git commit -m "feat(app): 拿掉 bottom nav，改成地球儀首頁的扁平路由"
```

---

### Task 11: 歷程與設定的返回鈕，並清掉 bottom nav 文案

**Files:**
- Create: `frontend/lib/shared/widgets/journal/floating_back_button.dart`
- Modify: `frontend/lib/features/journey/presentation/screens/journey_screen.dart`
- Modify: `frontend/lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `frontend/assets/translations/zh-TW.json`、`en.json`
- Test: `frontend/test/features/journey/presentation/screens/journey_screen_test.dart`
- Test: `frontend/test/features/settings/presentation/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: 無。
- Produces: `FloatingBackButton({Key? key, VoidCallback? onPressed})`，預設行為是 `context.pop()`，帶 `Key('floating-back')`。

- [ ] **Step 1: 寫失敗測試**

在 `journey_screen_test.dart` 與 `settings_screen_test.dart` 各加一題（沿用各檔既有的 override 與 fake）：

```dart
testWidgets(
  'given the journey screen pushed from home, '
  'when the user taps the back button, '
  'then it returns to the previous screen',
  (tester) async {
    await pumpRouterApp(
      tester,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(key: Key('home-screen')),
        ),
        GoRoute(path: '/journey', builder: (_, __) => const JourneyScreen()),
      ],
      overrides: [/* 沿用本檔既有的 overrides */],
    );
    final context = tester.element(find.byKey(const Key('home-screen')));
    GoRouter.of(context).push('/journey');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('floating-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
  },
);
```

`settings_screen_test.dart` 同樣一題，把 `/journey` 換成 `/settings`、`JourneyScreen` 換成 `SettingsScreen`。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/journey test/features/settings`
Expected: FAIL，找不到 `floating-back`

- [ ] **Step 3: 實作返回鈕**

建立 `frontend/lib/shared/widgets/journal/floating_back_button.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';

/// 浮在頁面左上角的返回鈕。
///
/// 歷程與設定原本是 bottom nav 的分頁，沒有返回的概念；改成從首頁 push
/// 之後就需要一個出口。做成浮動而不是 AppBar，是為了不動這兩頁既有的
/// Masthead 版面。
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 4,
      left: 14,
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: InkResponse(
          key: const Key('floating-back'),
          onTap: onPressed ?? () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.line),
              boxShadow: tokens.e2,
            ),
            child: Icon(Icons.chevron_left, size: 24, color: tokens.ink2),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 掛到兩個畫面上**

`journey_screen.dart` 的 `Scaffold` body 改成 `Stack`：

```dart
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(child: SingleChildScrollView(/* ...原本的 Column... */)),
          const FloatingBackButton(),
        ],
      ),
    );
```

`Masthead` 上方需要讓出返回鈕的位置——把 `Masthead` 包一層 `Padding(padding: const EdgeInsets.only(left: 48))` 之外更簡單的作法是在 `Column` 最前面加 `const SizedBox(height: 44)`。用後者，兩頁一致。

`settings_screen.dart` 同樣把 body 包成 `Stack`，在 `ListView` 的 children 最前面加 `const SizedBox(height: 44)`，再疊上 `const FloatingBackButton()`。

- [ ] **Step 5: 清掉 bottom nav 與舊故事列表文案**

`zh-TW.json` 與 `en.json` 移除整個 `bottom_nav` 物件，以及 `story` 物件內的 `list_eyebrow`、`list_title`、`list_empty` 三個 key（`deck_prev` / `deck_next` 仍被 `StoryDeck` 使用，留著）。

- [ ] **Step 6: 跑全部測試**

Run: `cd frontend && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全部 PASS、analyze 零問題

若有測試因為找不到 `bottom_nav.*` 而失敗，那是還有畫面在讀舊 key——用 `grep -rn "bottom_nav\|story.list_" frontend/lib` 找出來清掉，不要把 key 加回去。

- [ ] **Step 7: 提交**

```bash
git add -A frontend
git commit -m "feat(app): 歷程與設定加返回鈕，清掉 bottom nav 文案"
```

---

### Task 12: 實機驗收

自動化測試涵蓋不到的是「地球儀畫出來到底好不好看」與「轉場順不順」。這一步用實機跑一次。

**Files:** 無（只驗收，必要時回頭修）

- [ ] **Step 1: 跑起來**

用 `/run` skill 或 `cd frontend && fvm flutter run` 啟動 App。

- [ ] **Step 2: 逐項檢查**

- 地球儀陸地形狀正確，沒有破洞、沒有跨過球心的怪三角形，南極洲附近轉過去也正常。
- 拖曳旋轉順暢，上下轉到極限會停住而不是翻過去。
- 滑底部卡片，地球儀會轉到對應地點，紙卡 chip 跟著換。
- 第一張卡有「最新」徽章；沒有座標的故事在 rail 顯示正常。
- 點定位 → 地球儀放大淡出、卡片下滑、地圖淡入；地圖左上角地球儀鈕能回來。
- 搜尋輸入後跳建議，點建議進地圖並帶著關鍵字。
- 右上兩顆 icon 分別進歷程與設定，返回鈕能回首頁。

- [ ] **Step 3: 回報**

把每一項的實際結果如實回報給使用者（含沒過的項目與畫面截圖）。有問題就回到對應 task 修，不要在這裡累積「之後再說」的清單。

---

## Self-Review

**Spec coverage：**

| Spec 段落 | 對應 task |
|---|---|
| 架構與路由 | Task 10 |
| 資料層：每日故事座標 | Task 1、Task 2 |
| 地球儀元件（投影／裁切／輪廓／painter） | Task 3、4、5、6 |
| 首頁組成（頂部列、搜尋建議、定位鈕、rail） | Task 7、Task 9 |
| 詳細地圖模式（initialQuery、地球儀返回鈕） | Task 8 |
| 轉場 | Task 9（首頁端）、Task 10（路由端） |
| 歷程與設定返回鈕 | Task 11 |
| 測試 | 各 task 內建 |
| i18n | Task 8、9、11 |
| Analytics（新路由都給 name） | Task 10 |

**已知取捨：** spec 寫「解析放在背景 isolate」，Task 3 用 `compute`；`compute` 在 widget test 中會退化成同步執行，測試因此仍可斷言結果。spec 的「載入中先畫地球儀、資料到齊再淡入」在 Task 9 以 `valueOrNull ?? const []` 實現——輪廓還沒好時整顆球不畫，故事還沒好時 rail 顯示空狀態，符合意圖但沒有額外的淡入動畫；若實機驗收覺得突兀，在 Task 12 提出。
