"""把 journey_entries 缺的地點座標補回來。

兩段式：先用 place_id 的 Wikidata Q-id 查 P625；剩下查不到的（多半是
2026-04-25 探索頁改用 Wikipedia 之前存下來的 Google Places 記錄，place_id 是
ChIJ…）改用 place_address 做地理編碼。

用法：
    cd scripts && uv run python backfill_journey_entry_coords.py [--dry-run]

背景：`place_lat` / `place_lng` 是 20260819000000 才加的欄位，migration 明文
不回填，寫入端（0f2664da）也是同一天才進 App，所以那之前存下來的記錄座標
全是 null。書架頁的地球儀只釘有座標的記錄（`tripGlobePinsProvider`），
舊記錄因此一個點都不會出現。

記錄的 `place_id` 是探索頁存下來的 `wikidata:Q…`（見
places_repository_impl.dart），所以座標救得回來：拿 QID 查 P625 即可。與
backfill_place_coords.py 同一套作法，只是換一張表。

地址那一段刻意**只放在這裡、不做進 App**：Nominatim 的使用政策不接受大量的
客戶端批次查詢（每秒 1 次、要有可識別的 User-Agent），一次性從維運端跑才站得
住腳。App 端的回填維持只走 Wikidata（`BackfillJourneyCoordsUseCase`）。

不用名稱搜尋：量測過，用地名去 Wikipedia/Wikidata 搜尋，多數首位結果是別的
國家的同名建築（薩爾斯堡主教座堂 → 施派爾主教座堂、美景宮 → 華沙的美景宮、
洗馬池 → 四川洗象池）。錯的釘點比沒有釘點糟。地址是完整街址，精準得多。

`updated_at` 會一併推到現在。SyncEngine 是以 updated_at 比新舊、新的一邊覆蓋
另一邊（sync_engine.dart 的 fullSync），不推的話裝置上那份較新的本地記錄會在
下次同步時把補好的座標推回 null。
"""

from __future__ import annotations

import argparse
import re
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import requests
from dotenv import load_dotenv
from lorescape_publisher.config import Config
from supabase import create_client

REPO_ROOT = Path(__file__).resolve().parents[1]

_WIKIDATA_ENTITY_URL = "https://www.wikidata.org/wiki/Special:EntityData/{qid}.json"
_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "Lorescape/1.0 (https://lorescape.app; ops@lorescape.app)"
_WIKIDATA_PREFIX = "wikidata:"

# 地址裡的中文國名 → ISO 3166-1 alpha-2。
#
# 這張表同時是「剝掉什麼」與「驗證什麼」：Google Places 的中文地址把國名放在
# 最後（或台灣地址放在郵遞區號後面），留著會讓 Nominatim 查不到；而查回來的
# country_code 必須對得上，否則就是配到別的國家的同名地點，寧可不補。
_COUNTRY_CODES = {
    "台灣": "tw",
    "臺灣": "tw",
    "奧地利": "at",
    "捷克": "cz",
    "德國": "de",
    "匈牙利": "hu",
    "斯洛伐克": "sk",
    "波蘭": "pl",
    "義大利": "it",
    "法國": "fr",
    "日本": "jp",
}


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


def split_country(address: str) -> tuple[str, str] | None:
    """把地址拆成 (剝掉國名後的查詢字串, 預期的 country_code)。

    認不出國名就回 None——沒有國名就沒辦法驗證結果落在對的國家，那種情況下
    寧可不補。
    """
    for name, code in _COUNTRY_CODES.items():
        if name in address:
            return (address.replace(name, " ").strip(" ,、"), code)
    return None


def place_tokens(address: str) -> set[str]:
    """地址裡足以指認地點的詞：中文的縣市區鄉鎮里，與拉丁文的長字。

    國家對得上還不夠——「411臺灣臺中市太平區新坪里」查回來的第一名可能落在
    新北，country_code 一樣是 tw 就矇混過關了。所以再要求查回來的
    display_name 至少命中一個地名詞。
    """
    normalised = address.replace("臺", "台")
    tokens = set(re.findall(r"[\u4e00-\u9fff]{2,4}[市縣區鎮鄉村里]", normalised))
    tokens |= {w.lower() for w in re.findall(r"[A-Za-zÀ-ž]{4,}", address)}
    return tokens


def geocode(address: str) -> tuple[float, float] | None:
    """用地址查座標，並驗證落在地址所寫的國家。"""
    split = split_country(address)
    if split is None:
        return None
    query, expected_code = split

    response = requests.get(
        _NOMINATIM_URL,
        params={
            "q": query,
            "format": "json",
            "limit": 1,
            "addressdetails": 1,
        },
        headers={"User-Agent": _USER_AGENT},
        timeout=20,
    )
    # Nominatim 的使用政策：每秒最多一次。
    time.sleep(1.1)
    if response.status_code != 200:
        return None
    results = response.json()
    if not results:
        return None

    top = results[0]
    if (top.get("address") or {}).get("country_code") != expected_code:
        return None

    display = (top.get("display_name") or "").replace("臺", "台").lower()
    tokens = place_tokens(address)
    if tokens and not any(token.lower() in display for token in tokens):
        return None
    try:
        return (float(top["lat"]), float(top["lon"]))
    except (KeyError, TypeError, ValueError):
        return None


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
        .select("id, user_id, place_id, place_name, place_address")
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
        coords = None
        source = ""

        qid = qid_of(row["place_id"])
        if qid is not None:
            if qid not in cache:
                entity = fetch_entity(qid)
                cache[qid] = coords_from_entity(entity) if entity else None
            coords = cache[qid]
            source = f"P625 {qid}"

        # 第二段：Wikidata 查不到（或根本不是 wikidata id）就用地址。
        if coords is None and (row.get("place_address") or "").strip():
            coords = geocode(row["place_address"])
            source = "地址"

        if coords is None:
            why = "查不到 P625" if qid else f'place_id={row["place_id"]}'
            unresolved.append(f'{row["place_name"]}（{why}，地址也查不到）')
            continue

        lat, lon = coords
        print(f'  {row["place_name"]}: {lat}, {lon}  ({source})')
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
