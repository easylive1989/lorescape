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
