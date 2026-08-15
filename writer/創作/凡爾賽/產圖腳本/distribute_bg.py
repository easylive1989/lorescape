#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""依各篇 story.json 宣告的 backgrounds，把 美術測試/ 的圖分發進故事資料夾。

與 distribute.py 的分工：那支管立繪與 CG（要手寫對應表，因為檔名不同）；
這支管背景——**背景不需要對應表，story.json 自己就宣告了要哪幾張**，
掃出來複製即可。手寫對應表遲早會跟 story.json 分岔。
"""
import json, pathlib, shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "美術測試"

copied, missing = 0, []
for d in sorted((ROOT / "stories").iterdir()):
    sj = d / "story.json"
    if not sj.exists():
        continue
    story = json.loads(sj.read_text(encoding="utf-8"))
    dst = d / "assets" / "backgrounds"
    dst.mkdir(parents=True, exist_ok=True)
    for filename in set(story["backgrounds"].values()):
        s = SRC / filename
        if not s.exists():
            missing.append(f"{d.name}: {filename}")
            continue
        shutil.copy2(s, dst / filename)
        copied += 1

print("複製 %d 張背景" % copied)
if missing:
    print("⚠️ 來源缺少：")
    for m in missing:
        print("   ", m)
