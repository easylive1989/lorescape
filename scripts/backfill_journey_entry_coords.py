"""把 journey_entries 缺的地點座標從 Wikidata P625 補回來。

用法：
    cd scripts && uv run python backfill_journey_entry_coords.py [--dry-run]

背景：`place_lat` / `place_lng` 是 20260819000000 才加的欄位，migration 明文
不回填，寫入端（0f2664da）也是同一天才進 App，所以那之前存下來的記錄座標
全是 null。書架頁的地球儀只釘有座標的記錄（`tripGlobePinsProvider`），
舊記錄因此一個點都不會出現。

記錄的 `place_id` 是探索頁存下來的 `wikidata:Q…`（見
places_repository_impl.dart），所以座標救得回來：拿 QID 查 P625 即可。與
backfill_place_coords.py 同一套作法，只是換一張表。

`updated_at` 會一併推到現在。SyncEngine 是以 updated_at 比新舊、新的一邊覆蓋
另一邊（sync_engine.dart 的 fullSync），不推的話裝置上那份較新的本地記錄會在
下次同步時把補好的座標推回 null。
"""

from __future__ import annotations

import argparse
import sys
from datetime import UTC, datetime
from pathlib import Path

import requests
from dotenv import load_dotenv
from lorescape_publisher.config import Config
from supabase import create_client

REPO_ROOT = Path(__file__).resolve().parents[1]

_WIKIDATA_ENTITY_URL = "https://www.wikidata.org/wiki/Special:EntityData/{qid}.json"
_USER_AGENT = "Lorescape/1.0 (https://lorescape.app; ops@lorescape.app)"
_WIKIDATA_PREFIX = "wikidata:"


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


def qid_of(place_id: str) -> str | None:
    """`wikidata:Q42` → `Q42`。其他來源的 id（若真的存在）回 None。"""
    if not place_id.startswith(_WIKIDATA_PREFIX):
        return None
    qid = place_id[len(_WIKIDATA_PREFIX) :]
    return qid if qid.startswith("Q") else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # Supabase 憑證放在 publisher/.env，與 backfill_place_coords.py 同慣例。
    load_dotenv(REPO_ROOT / "publisher" / ".env")
    config = Config.from_env()
    supabase = create_client(config.supabase_url, config.supabase_service_role_key)

    rows = (
        supabase.table("journey_entries")
        .select("id, user_id, place_id, place_name")
        .is_("place_lat", "null")
        .execute()
        .data
    )
    print(f"待補座標的記錄：{len(rows)} 筆")

    # QID 相同的記錄不必重查（同一個地點常被存成多筆不同語言的記錄）。
    cache: dict[str, tuple[float, float] | None] = {}
    unresolved: list[str] = []
    filled = 0

    for row in rows:
        qid = qid_of(row["place_id"])
        if qid is None:
            unresolved.append(f'{row["place_name"]}（place_id={row["place_id"]}，非 wikidata）')
            continue

        if qid not in cache:
            entity = fetch_entity(qid)
            cache[qid] = coords_from_entity(entity) if entity else None
        coords = cache[qid]

        if coords is None:
            unresolved.append(f'{row["place_name"]}（{qid} 查不到 P625）')
            continue

        lat, lon = coords
        print(f'  {row["place_name"]}: {lat}, {lon}')
        if not args.dry_run:
            supabase.table("journey_entries").update(
                {
                    "place_lat": lat,
                    "place_lng": lon,
                    "updated_at": datetime.now(UTC).isoformat(),
                }
            ).eq("user_id", row["user_id"]).eq("id", row["id"]).execute()
        filled += 1

    print(f"\n補上座標：{filled} 筆" + ("（dry-run，未寫入）" if args.dry_run else ""))
    if unresolved:
        print("\n補不到、維持 null（地球儀上不會有這些點）：")
        for item in unresolved:
            print(f"  - {item}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
