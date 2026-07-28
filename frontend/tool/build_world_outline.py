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
