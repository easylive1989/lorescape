#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把美術測試/ 的定版圖分派進各故事資料夾，並把 story.json 的 missingAssets
轉成正式的 characters.sprites 宣告。

與龐貝版的差異：龐貝的 characters 一開始就寫了 sprites 檔名，distribute.py
只負責複製檔案與刪掉 missingAssets 條目。凡爾賽的 characters 是 `sprites:null`
起家的（立繪還沒畫時要能先進引擎跑文字），所以這支腳本多做一件事：
**把 sprites 填回 characters**。

用法: python3 distribute.py [--check]
    --check 只報告缺什麼，不寫檔。
"""
import io, json, os, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "美術測試")

# 故事資料夾 -> 角色 -> {表情: 來源檔名}
#
# 目的檔名一律由「角色_表情.png」組出來，不手寫——手寫兩份檔名遲早會分岔，
# 而分岔的症狀是引擎靜默顯示不出立繪（spritePath 對未知 key 回 null）。
SPRITES = {
    "01_擋板": {
        "anne": {"neutral": "ch_anne_base.png", "flat": "ch_anne_flat.png",
                 "asking": "ch_anne_asking.png"},
        "jacquot": {"neutral": "ch_jacquot_base.png", "eager": "ch_jacquot_eager.png"},
        "bertin": {"neutral": "ch_bertin_base.png", "pressing": "ch_bertin_pressing.png"},
    },
    "02_二十公里": {
        "catherine": {
            "neutral": "ch_catherine_base.png",
            "firm": "ch_catherine_firm.png",
            "weary": "ch_catherine_weary.png",
            "softened": "ch_catherine_softened.png",
        },
        "perrine": {
            "neutral": "ch_perrine_base.png",
            "pale": "ch_perrine_pale.png",
            "breaking": "ch_perrine_breaking.png",
        },
        "maillard": {
            "neutral": "ch_maillard_base.png",
            "raised": "ch_maillard_raised.png",
        },
    },
    "03_柵欄的兩邊": {
        "officer": {"neutral": "ch_officer_base.png", "tired": "ch_officer_tired.png",
                    "hard": "ch_officer_hard.png"},
        # 2️⃣ 的主角在這裡第一次露臉——玩家用眼睛認出來，不用文字。
        "marguerite": {"neutral": "ch_marguerite_base.png",
                       "worn": "ch_marguerite_worn.png"},
    },
    "04_三天份的行李": {
        "suzanne": {"neutral": "ch_suzanne_base.png", "guarded": "ch_suzanne_guarded.png"},
        "gervais": {"neutral": "ch_gervais_base.png", "stopped": "ch_gervais_stopped.png"},
        # 8️⃣ 的主角在這裡當配角。
        "etienne": {"neutral": "ch_etienne_base.png", "asking": "ch_etienne_asking.png"},
    },
    "05_陽台": {
        "sergeant": {"neutral": "ch_sergeant_base.png", "grim": "ch_sergeant_grim.png",
                     "relief": "ch_sergeant_relief.png"},
    },
    "06_牛奶": {
        "gardener": {"neutral": "ch_gardener_base.png", "dry": "ch_gardener_dry.png"},
    },
    "07_麵包師傅一家": {
        # 「媽媽」＝ 2️⃣ 的主角。立繪沿用，全篇不給名字。
        "marguerite": {"neutral": "ch_marguerite_base.png",
                       "worn": "ch_marguerite_worn.png"},
        "womana": {"neutral": "ch_womana_base.png", "certain": "ch_womana_certain.png",
                   "laughing": "ch_womana_laughing.png"},
    },
    "08_今晚不點了": {
        "gervais": {"neutral": "ch_gervais_base.png", "stopped": "ch_gervais_stopped.png"},
        "clerk": {"neutral": "ch_clerk_base.png", "flat": "ch_clerk_flat.png"},
    },
}

# 背景／CG。
#
# ⚠️ CG 放在 assets/backgrounds/ 而不是另開一個 cg/ 目錄——這是引擎既有的約定
# （pack_repository.dart 的 cgPath() 就是去 backgrounds/ 找），不要「順手」改。
#
# 🔑 鞋是 4 張不是 3 張。第一篇_場景清單 §5.1 原本估 3（濕透／壞掉／停下），
# 排場時發現少了基準：沒有「乾的」那一張，後面三張的遞進就沒有起點。
BGS: dict[str, dict[str, str]] = {
    # 其餘七篇各挑一到兩張全螢幕實繪；未繪的仍宣告在 missingAssets，
    # 引擎對缺件的 cg 回 null 不崩，**而且對話框照樣關掉，節奏還在**。
    "01_擋板": {"cg_01_shelf.png": "cg_01_shelf.png"},
    "03_柵欄的兩邊": {"cg_03_staying.png": "cg_03_staying.png"},
    "04_三天份的行李": {"cg_04_trunk.png": "cg_04_trunk.png"},
    "05_陽台": {"cg_05_balcony.png": "cg_05_balcony.png"},
    "06_牛奶": {"cg_06_milk.png": "cg_06_milk.png"},
    "07_麵包師傅一家": {"cg_07_knots.png": "cg_07_knots.png"},
    "08_今晚不點了": {"cg_08_lastlight.png": "cg_08_lastlight.png"},
    "02_二十公里": {
        "cg_fish.png": "cg_fish.png",
        "cg_shoe_dry.png": "cg_shoe_dry.png",
        "cg_shoe_wet.png": "cg_shoe_wet.png",
        "cg_shoe_broken.png": "cg_shoe_broken.png",
        "cg_shoe_still.png": "cg_shoe_still.png",
        "cg_gate_shut.png": "cg_gate_shut.png",
    },
}


def main(check_only: bool = False) -> int:
    missing, copied = [], 0

    for folder, characters in SPRITES.items():
        dst_dir = os.path.join(ROOT, "stories", folder, "assets", "sprites")
        for who, expressions in characters.items():
            for expression, src in expressions.items():
                s = os.path.join(SRC, src)
                if not os.path.exists(s):
                    missing.append(src)
                    continue
                if not check_only:
                    os.makedirs(dst_dir, exist_ok=True)
                    shutil.copy2(s, os.path.join(dst_dir, f"{who}_{expression}.png"))
                copied += 1

    for folder, mapping in BGS.items():
        dst_dir = os.path.join(ROOT, "stories", folder, "assets", "backgrounds")
        for dst, src in mapping.items():
            s = os.path.join(SRC, src)
            if not os.path.exists(s):
                missing.append(src)
                continue
            if not check_only:
                os.makedirs(dst_dir, exist_ok=True)
                shutil.copy2(s, os.path.join(dst_dir, dst))
            copied += 1

    if missing:
        print("⚠️ 來源缺少 %d 個: %s" % (len(missing), ", ".join(sorted(set(missing)))))
    if check_only:
        print("（--check：沒有寫入任何檔案）%d 個可複製" % copied)
        return 1 if missing else 0
    print("複製 %d 個檔案" % copied)

    # story.json：把 sprites 填回 characters，並刪掉已滿足的 missingAssets。
    for folder, characters in SPRITES.items():
        p = os.path.join(ROOT, "stories", folder, "story.json")
        d = json.load(io.open(p, encoding="utf-8"))
        sdir = os.path.join(ROOT, "stories", folder, "assets", "sprites")
        changed = []
        for who, expressions in characters.items():
            have = {e: f"{who}_{e}.png" for e in expressions
                    if os.path.exists(os.path.join(sdir, f"{who}_{e}.png"))}
            # 只有整組表情都到齊才填——半組會讓劇本裡引用到缺的那個表情時
            # 靜默沒有立繪，比整個角色沒立繪更難發現。
            if have and len(have) == len(expressions):
                d["characters"][who]["sprites"] = have
                changed.append(who)

        bdir = os.path.join(ROOT, "stories", folder, "assets", "backgrounds")

        def satisfied(item):
            t = item.get("type")
            ids = item.get("ids") or ([item["id"]] if item.get("id") else [])
            if t == "sprite":
                return all(os.path.exists(os.path.join(sdir, i + ".png")) for i in ids)
            if t in ("background", "cg"):
                # 🔑 只把「已經畫好的」從 ids 裡剔掉，整組畫完才刪條目。
                # 半組就刪條目的話，引擎會去找還沒畫的那幾張而不是回 null。
                item["ids"] = [i for i in ids
                               if not os.path.exists(os.path.join(bdir, i + ".png"))]
                return not item["ids"]
            return False

        before = len(d.get("missingAssets", []))
        d["missingAssets"] = [m for m in d.get("missingAssets", []) if not satisfied(m)]
        json.dump(d, io.open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        io.open(p, "a", encoding="utf-8").write("\n")
        print("%-16s 立繪填回 %s｜missingAssets %d -> %d"
              % (folder, ",".join(changed) or "（無）", before, len(d["missingAssets"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(check_only="--check" in sys.argv))
