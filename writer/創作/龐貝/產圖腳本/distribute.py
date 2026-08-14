#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把美術測試/ 的定版圖分派進各故事資料夾，並清掉 story.json 已滿足的 missingAssets。"""
import json, os, shutil, io, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "美術測試")

# 故事資料夾 -> {目的檔名: 來源檔名}
SPRITES = {
 "02_烤爐熄了": {
   "lender_neutral.png": "ch_lender_base.png",
   "lender_hard.png": "ch_lender_hard.png",
   "lender_tired.png": "ch_lender_tired.png",
   "zabda_neutral.png": "ch_zabda_base.png"},
 "03_井水退了": {
   "priest_neutral.png": "ch_priest_base.png",
   "priest_guarded.png": "ch_priest_guarded.png",
   "priest_weary.png": "ch_priest_weary.png",
   "patron_neutral.png": "ch_patron_base.png",
   "patron_cold.png": "ch_patron_cold.png"},
 "04_天上那棵樹": {
   "thea_neutral.png": "ch_thea_base.png",
   "thea_stern.png": "ch_thea_stern.png",
   "thea_afraid.png": "ch_thea_afraid.png",
   "salvia_neutral.png": "ch_salvia_base.png",
   "salvia_busy.png": "ch_salvia_busy.png",
   "orestes_neutral.png": "ch_orestes_base.png",
   "orestes_calm.png": "ch_orestes_calm.png"},
 "05_蠟板": {
   "master_neutral.png": "ch_master_base.png",
   "master_impatient.png": "ch_master_impatient.png",
   "master_afraid.png": "ch_master_afraid.png",
   "steward_neutral.png": "ch_steward_base.png",
   "steward_urgent.png": "ch_steward_urgent.png",
   "hylas_neutral.png": "ch_hylas_base.png",
   "hylas_scared.png": "ch_hylas_scared.png"},
 "06_上鎖的門": {
   "orestes_neutral.png": "ch_orestes_base.png",
   "orestes_calm.png": "ch_orestes_calm.png",
   "orestes_urgent.png": "ch_orestes_urgent.png",
   "lender_neutral.png": "ch_lender_base.png",
   "lender_tired.png": "ch_lender_tired.png",
   "hylas_neutral.png": "ch_hylas_base.png",
   "hylas_scared.png": "ch_hylas_scared.png"},
 "07_靠不了岸": {
   "pliny_neutral.png": "ch_pliny_base.png",
   "pliny_curious.png": "ch_pliny_curious.png",
   "pliny_labored.png": "ch_pliny_labored.png",
   "officer_neutral.png": "ch_officer_base.png",
   "officer_hard.png": "ch_officer_hard.png"},
 "08_普特奧利的新房子": {
   "survivor_neutral.png": "ch_survivor_base.png",
   "survivor_sharp.png": "ch_survivor_sharp.png",
   "zabda_neutral.png": "ch_zabda_base.png"},
}

# 背景／CG
BGS = {
 "01_港口的外地人": {"cg_column_rising.png": "cg_column_rising.png"},
 "04_天上那棵樹":   {"cg_column_rising.png": "cg_column_rising.png"},
 "05_蠟板":         {"bg_street_ash.png": "bg_street_ash.png",
                     "bg_atrium_collapse.png": "bg_atrium_collapse.png"},
 "06_上鎖的門":     {"bg_street_ash.png": "bg_street_ash.png"},
 "07_靠不了岸":     {"cg_column_rising.png": "cg_column_rising.png"},
 "08_普特奧利的新房子": {"bg_puteoli.png": "bg_puteoli.png"},
}

missing_src = []
copied = 0
for folder, mapping in list(SPRITES.items()):
    dst_dir = os.path.join(ROOT, "stories", folder, "assets", "sprites")
    for dst, src in mapping.items():
        s = os.path.join(SRC, src)
        if not os.path.exists(s):
            missing_src.append(src); continue
        shutil.copy2(s, os.path.join(dst_dir, dst)); copied += 1
for folder, mapping in list(BGS.items()):
    dst_dir = os.path.join(ROOT, "stories", folder, "assets", "backgrounds")
    for dst, src in mapping.items():
        s = os.path.join(SRC, src)
        if not os.path.exists(s):
            missing_src.append(src); continue
        shutil.copy2(s, os.path.join(dst_dir, dst)); copied += 1

print("複製 %d 個檔案" % copied)
if missing_src:
    print("⚠️ 來源缺少: %s" % ", ".join(sorted(set(missing_src))))

# 清掉已滿足的 missingAssets 條目，並補上 04 的 orestes 角色宣告
for folder in sorted(os.listdir(os.path.join(ROOT, "stories"))):
    p = os.path.join(ROOT, "stories", folder, "story.json")
    if not os.path.exists(p):
        continue
    d = json.load(io.open(p, encoding="utf-8"))
    sdir = os.path.join(ROOT, "stories", folder, "assets", "sprites")
    bdir = os.path.join(ROOT, "stories", folder, "assets", "backgrounds")

    def satisfied(item):
        t = item.get("type")
        ids = item.get("ids") or ([item["id"]] if item.get("id") else [])
        if t == "sprite":
            return all(os.path.exists(os.path.join(sdir, i + ".png")) for i in ids)
        if t in ("background", "cg"):
            return all(os.path.exists(os.path.join(bdir, i + ".png")) for i in ids)
        return False

    before = len(d.get("missingAssets", []))
    d["missingAssets"] = [m for m in d.get("missingAssets", []) if not satisfied(m)]
    after = len(d["missingAssets"])
    if before != after:
        json.dump(d, io.open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print("%-22s missingAssets %d -> %d" % (folder, before, after))
