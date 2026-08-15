#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把七篇劇本 markdown 組裝成 story.json。

    python3 build_stories.py [篇資料夾名 ...]      # 預設全部

流程：`md2story.py` 抽骨架（機械）→ 本檔補設計（變數、角色、結局判定）。
**設計的部分全部寫在下面的 SPEC 裡，不從 markdown 猜**——猜錯會靜默壞掉。

第 2 篇（二十公里）不在這裡：它是手工建的垂直切片，story.json 已定版，
**不要用這支腳本蓋掉它**。
"""
import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT.parents[1] / "製作規範/md2story.py"

# ── 每篇的設計規格 ─────────────────────────────────────────────────────
# vars:      中文變數名 → (英文 key, 標籤)
# chars:     劇本裡的稱呼 → (角色 key, 顯示名, 是否主角, 表情清單)
# bg:        場 id → 背景 key（背景 key → 檔名寫在 backgrounds）
# endings:   結局 id → (標題, 備註)
# resolve:   最後一場結束時的結局判定，依序比對，第一個成立者勝
SPEC = {
"01_擋板": {
  "bgm_default": "dawn", "bgm": {'S05': 'tension', 'S06': 'tension'},
  "ifconds": {"S07": {"var": "credit", "op": ">=", "value": 2}},
  "meta": {"id": "versailles_01_the_shutter", "order": 1, "title": "擋板",
           "subtitle": "十月五日，拂曉", "minutes": 12},
  "vars": {"信用": ("credit", "信用"), "留了多少": ("held", "留了多少")},
  "chars": {"皮耶": ("pierre", "皮耶", True, []),
            "安妮": ("anne", "安妮", False, ["neutral"]),
            "雅各": ("jacquot", "雅各", False, ["neutral"]),
            "貝爾坦太太": ("bertin", "貝爾坦太太", False, ["neutral"]),
            "老人": ("oldman", "老人", False, []),
            "一個女人": ("woman", "一個女人", False, []),
            "另一個": ("woman2", "另一個", False, []),
            "一個男人": ("man", "一個男人", False, [])},
  "backgrounds": {"bakery": "bg_paris_bakery.png", "street": "bg_paris_bakery.png"},
  "bg": {"S01": "bakery", "S02": "bakery", "S03": "bakery", "S04": "bakery",
         "S05": "bakery", "S06": "bakery", "S07": "street", "S08": "bakery",
         "E_A": "street", "E_B": "bakery", "E_C": "bakery"},
  "endings": {"A": ("先到先給", "照順序給完，之後那條街上最長的隊伍在他門口"),
              "B": ("留給熟客", "「那家要看你是誰。」二十二年來第一次知道別人怎麼講他"),
              "C": ("藏起來", "爐子後面那兩個。安妮那天晚上沒有跟他說話，之後也沒有再提過")},
  "resolve": [({"var": "held", "op": ">=", "value": 2}, "E_C"),
              ({"var": "credit", "op": ">=", "value": 2}, "E_A"),
              (None, "E_B")],
},
"03_柵欄的兩邊": {
  "bgm_default": "tension", "bgm": {'S05': 'quiet', 'S06': 'tension'},
  "meta": {"id": "versailles_03_both_sides", "order": 3, "title": "柵欄的兩邊",
           "subtitle": "十月五日，午後到傍晚", "minutes": 13},
  "vars": {"認了": ("owned", "認了"), "門": ("gate", "門")},
  "chars": {"尼可拉": ("nicolas", "尼可拉", True, []),
            "中尉": ("officer", "中尉", False, ["neutral"]),
            "瑪格麗特": ("marguerite", "瑪格麗特", False, ["neutral"])},
  "backgrounds": {"gate": "bg_palace_gate.png"},
  "bg": {k: "gate" for k in
         ["S01","S02","S03","S04","S05","S06","S07","E_A","E_B","E_C"]},
  "endings": {"A": ("開口", "「那你站好」——而他後來真的站好了，站好完全沒有用"),
              "B": ("沒看見", "不叫那一聲，不是因為他算過"),
              "C": ("拉進來", "他把門開了一個人的寬度，而拒絕的人是外面那一個")},
  # 最終選擇在 S07，三個選項直接指定結局；此處只留保險判定。
  "resolve": [({"var": "gate", "op": ">=", "value": 2}, "E_C"),
              ({"var": "owned", "op": ">=", "value": 2}, "E_A"),
              (None, "E_B")],
},
"04_三天份的行李": {
  "bgm_default": "quiet", "bgm": {'S04': 'night', 'S07': 'tension'},
  "meta": {"id": "versailles_04_three_days", "order": 4, "title": "三天份的行李",
           "subtitle": "十月五日，傍晚到深夜", "minutes": 13},
  "vars": {"多放了": ("extra", "多放了"), "說了": ("told", "說了")},
  "chars": {"瑪麗": ("marie", "瑪麗", True, []),
            "蘇珊": ("suzanne", "蘇珊", False, ["neutral"]),
            "熱維太太": ("gervais", "熱維太太", False, ["neutral"]),
            "老僕役": ("etienne", "提燈的老人", False, ["neutral"])},
  "backgrounds": {"passage": "bg_servants_passage.png",
                  "chamber": "bg_queens_chamber.png",
                  "mirrors": "bg_hall_of_mirrors.png"},
  "bg": {"S01": "passage", "S02": "chamber", "S03": "chamber", "S04": "mirrors",
         "S05": "chamber", "S06": "passage", "S07": "passage", "S08": "chamber",
         "E_A": "chamber", "E_B": "chamber", "E_C": "passage"},
  "endings": {"A": ("三天份", "交代是三天，她做的就是三天。十月底有人回來拿厚衣服"),
              "B": ("冬衣", "壓在最底下。沒有人打開它，也沒有人問她為什麼這麼重"),
              "C": ("我去告訴別人", "整層樓的燭光一盞一盞亮起來，而沒有一個人講話")},
  "resolve": [({"var": "told", "op": ">=", "value": 2}, "E_C"),
              ({"var": "extra", "op": ">=", "value": 2}, "E_B"),
              (None, "E_A")],
},
"05_陽台": {
  "bgm_default": "tension", "bgm": {'S05': 'quiet', 'S06': 'still'},
  "meta": {"id": "versailles_05_the_balcony", "order": 5, "title": "陽台",
           "subtitle": "十月六日，凌晨到上午", "minutes": 13},
  "vars": {"護兵": ("shield_guard", "護兵"), "護民": ("shield_crowd", "護民")},
  "chars": {"安端": ("antoine", "安端", True, []),
            "士官": ("sergeant", "士官", False, ["neutral"]),
            "一個聲音": ("voice", "一個聲音", False, []),
            "另一個聲音": ("voice2", "另一個聲音", False, [])},
  "backgrounds": {"cour": "bg_cour_de_marbre.png",
                  "passage": "bg_servants_passage.png",
                  "road": "bg_versailles_road.png"},
  "bg": {"S01": "passage", "S02": "cour", "S03": "cour", "S04": "cour",
         "S05": "cour", "S06": "cour", "S07": "cour",
         "E_A": "road", "E_B": "road", "E_C": "road"},
  "endings": {"A": ("擋在衛兵前面", "他沒有說，不是因為怕，是他一直不確定那件事該叫什麼"),
              "B": ("擋在群眾前面", "「那不是一個故事。」"),
              "C": ("什麼都沒做", "他在場，而別人講的那些他一樣都沒看見")},
  "resolve": [({"var": "shield_guard", "op": ">=", "value": 2}, "E_A"),
              ({"var": "shield_crowd", "op": ">=", "value": 2}, "E_B"),
              (None, "E_C")],
},
"06_牛奶": {
  "bgm_default": "quiet", "bgm": {'S05': 'still', 'S07': 'still'},
  "ifconds": {"S04": {"var": "mine", "op": ">=", "value": 1}},
  "meta": {"id": "versailles_06_the_milk", "order": 6, "title": "牛奶",
           "subtitle": "十月六日，清晨", "minutes": 12},
  "vars": {"等": ("waiting", "等"), "自己": ("mine", "自己")},
  "chars": {"雅克": ("jacques", "雅克", True, []),
            "修樹的": ("gardener", "修樹的", False, ["neutral"])},
  "backgrounds": {"hameau": "bg_hameau.png", "canal": "bg_park_canal.png"},
  "bg": {"S01": "hameau", "S02": "hameau", "S03": "hameau", "S04": "canal",
         "S05": "hameau", "S06": "hameau", "S07": "hameau",
         "E_A": "hameau", "E_B": "hameau", "E_C": "hameau"},
  "endings": {"A": ("倒掉", "每天準時起床，做完一整套事情，然後把成果倒在地上"),
              "B": ("自己喝掉", "前面三年他記得的事情很少，後面那一年多什麼都記得"),
              "C": ("等到天黑", "他倒掉的那一天，才是它結束的那一天——而那一天是他決定的")},
  # 修正條件段之後選擇點剩 4 個，變數上限跟著降；門檻重調過，
  # 讓 A（倒掉）不再被 B、C 完全遮蔽——走訪測試抓到過 A 不可達。
  "resolve": [({"var": "waiting", "op": ">=", "value": 3}, "E_C"),
              ({"var": "mine", "op": ">=", "value": 3}, "E_B"),
              (None, "E_A")],
},
"07_麵包師傅一家": {
  "bgm_default": "quiet", "bgm": {'S02': 'tension', 'S06': 'tension'},
  "ifconds": {"S05": {"var": "saw", "op": ">=", "value": 2}},
  "meta": {"id": "versailles_07_the_bakers_family", "order": 7,
           "title": "麵包師傅一家", "subtitle": "十月六日，午後到夜", "minutes": 12},
  "vars": {"跟緊": ("close", "跟緊"), "看見": ("saw", "看見")},
  "chars": {"馬丹": ("martin", "馬丹", True, []),
            "媽媽": ("marguerite", "媽媽", False, ["neutral"]),
            "女人甲": ("womana", "女人甲", False, ["neutral"]),
            "女人乙": ("womanb", "女人乙", False, [])},
  "backgrounds": {"gate": "bg_palace_gate.png", "road": "bg_versailles_road.png",
                  "street": "bg_paris_bakery.png"},
  "bg": {"S01": "gate", "S02": "road", "S03": "road", "S04": "road",
         "S05": "road", "S06": "street", "S07": "street",
         "E_A": "street", "E_B": "street", "E_C": "road"},
  "endings": {"A": ("跟緊", "隔天早上他第一次發現，媽媽也會把鞋帶打兩次結"),
              "B": ("跑到前面", "「你以為那是什麼。」——他到那時候都還沒問過自己"),
              "C": ("落在最後", "每個人的答案都不一樣，而且每個人都很確定")},
  # 同 6️⃣：門檻重調，讓 C（落在最後）有路徑走得到。
  "resolve": [({"var": "close", "op": ">=", "value": 3}, "E_A"),
              ({"var": "saw", "op": ">=", "value": 3}, "E_B"),
              (None, "E_C")],
},
"08_今晚不點了": {
  "bgm_default": "night", "bgm": {'S05': 'quiet', 'S07': 'still'},
  "meta": {"id": "versailles_08_no_lamps_tonight", "order": 8,
           "title": "今晚不點了", "subtitle": "十月六日夜，到數日後", "minutes": 13},
  "vars": {"照做": ("routine", "照做"), "問": ("asked", "問")},
  "chars": {"艾提安": ("etienne", "艾提安", True, []),
            "熱維太太": ("gervais", "熱維太太", False, ["neutral"]),
            "清點的人": ("clerk", "清點的人", False, ["neutral"]),
            "廚房的": ("kitchen", "廚房的", False, []),
            "一個人": ("someone", "一個人", False, [])},
  "backgrounds": {"passage": "bg_servants_passage.png",
                  "mirrors": "bg_hall_of_mirrors.png"},
  "bg": {"S01": "passage", "S02": "mirrors", "S03": "passage", "S04": "passage",
         "S05": "mirrors", "S06": "passage", "S07": "passage",
         "E_A": "mirrors", "E_B": "passage", "E_C": "mirrors"},
  "endings": {"A": ("照常點完", "他這輩子做的最後一件事，是決定今天不上去"),
              "B": ("點一半就停", "那是一件很小的事——他只是沒辦法解釋為什麼站了那麼久"),
              "C": ("點完之後自己吹熄", "它是在他吹熄鏡廳最後一盞的時候結束的")},
  # 門檻 3 不是 2：兩個變數各有 5 個加點機會，門檻 2 會讓 B（點一半就停）
  # 被 A、C 完全遮蔽——走訪測試抓到過 B 不可達。
  "resolve": [({"var": "asked", "op": ">=", "value": 3}, "E_C"),
              ({"var": "routine", "op": ">=", "value": 3}, "E_A"),
              (None, "E_B")],
},
}


# 各篇 `FULL:` 依出現順序對應的 cg id。
# 只有下面標 ⭐ 的會實際繪製（gencg2.sh），其餘留在 missingAssets——
# 引擎對缺件的 cg 回 null 不會崩，**而且對話框照樣關掉，那一格的節奏還在**。
CG_IDS = {
  "01_擋板":        ["cg_01_open", "cg_01_shelf"],                      # ⭐ shelf
  "03_柵欄的兩邊":   ["cg_03_face", "cg_03_staying"],                    # ⭐ staying
  "04_三天份的行李": ["cg_04_empty", "cg_04_coat", "cg_04_mirrors", "cg_04_trunk"],  # ⭐ trunk
  "05_陽台":        ["cg_05_musket", "cg_05_crush", "cg_05_corridor", "cg_05_balcony"],  # ⭐ balcony
  "06_牛奶":        ["cg_06_pail", "cg_06_door", "cg_06_hameau", "cg_06_milk"],  # ⭐ milk
  "07_麵包師傅一家": ["cg_07_shoes", "cg_07_faces", "cg_07_boxes", "cg_07_torches", "cg_07_knots"],  # ⭐ knots
  "08_今晚不點了":   ["cg_08_lamp", "cg_08_mirrors", "cg_08_basket", "cg_08_sheets",
                     "cg_08_empty", "cg_08_lastlight"],                 # ⭐ lastlight
}

# 全篇共用的音效／音樂缺件宣告。音檔一張都還沒有，先宣告讓引擎降級。
MISSING_AUDIO = [
    {"type": "bgm", "ids": ["dawn", "tension", "quiet", "rain", "night", "still"],
     "note": "6 首撐完全包；本包幾乎全程室內或雨中"},
    {"type": "sfx", "ids": ["footsteps", "door", "rain", "crowd_low", "fire",
                            "metal", "cloth", "bell"],
     "note": "通用組，跨篇共用"},
]


def build(folder: str) -> dict:
    d = ROOT / "stories" / folder
    spec = SPEC[folder]
    raw = subprocess.run([sys.executable, str(TOOL), str(d / "script.md")],
                         capture_output=True, text=True, check=True).stdout
    sk = json.loads(raw)

    varmap = {zh: en for zh, (en, _) in spec["vars"].items()}
    charmap = {zh: key for zh, (key, *_ ) in spec["chars"].items()}
    cgs: set[str] = set()

    def fix(nodes: list) -> list:
        out = []
        for n in nodes:
            t = n.get("t")
            if t == "show":
                who = charmap.get(n.pop("_who", "").replace("ch_", "").replace("_base", ""))
                if who is None:
                    continue
                n["who"] = who
                n["sprite"] = "neutral"
            elif t == "d":
                who = charmap.get(n.pop("_who", ""))
                if who is None:
                    n = {"t": "n", "text": n["text"]}
                else:
                    n["who"] = who
            elif t == "cg":
                ids = CG_IDS.get(folder, [])
                idx = len([c for c in cgs])
                n["id"] = ids[idx] if idx < len(ids) else "cg_%s_x%d" % (
                    folder.split("_")[0], idx)
                cgs.add(n["id"])
            elif t == "choice":
                for o in n["options"]:
                    o.pop("_raw", None)
                    add = o.pop("_add", None)
                    if add:
                        o["add"] = {varmap[k]: v for k, v in add.items() if k in varmap}
                    then = o.pop("_then", None)
                    goto = o.pop("_goto", None)
                    cond = o.pop("_cond", None)
                    # 🔑 引擎契約：then 與 goto 互斥（story_tool.py check 1.5）
                    if goto:
                        o["goto"] = goto
                    elif then:
                        o["then"] = [{"t": "n", "text": x} for x in then]
                    if cond and cond["var"] in varmap:
                        o.setdefault("_note", "條件選項，待人工確認")
            out.append(n)
        return out

    OPS = {"≥": ">=", "≤": "<=", "＝": "==", "=": "==", ">": ">", "<": "<"}

    def mark_cond(raw: str):
        """把 `IF ...` 的內容轉成引擎的 cond。回傳 (cond, 是否為 else 段)。

        劇本裡有兩種寫法，**兩種都要認**：
          1. `IF 留了多少 ≥ 2` / `IF 留了多少 ≤ 1`  ← 變數型，條件直接寫在標記裡
          2. `IF 選了 S06 ③` / `IF 未選 S06 ③`      ← 選項型，條件要從 SPEC 查

        只處理其中一種的話，另一種會被攤平成直線——實測 6️⃣7️⃣ 因此各有一個
        結局永遠到不了，走訪測試抓到的。
        """
        if raw.startswith(("選了", "未選")):
            return spec["ifconds"][sid], raw.startswith("未選")
        m = re.match(r"(\S+)\s*([≥≤＝=><])\s*(-?\d+)", raw)
        if not m:
            raise ValueError("看不懂的 IF 標記：%s @ %s/%s" % (raw, folder, sid))
        name = m.group(1)
        # 變數名可能已是英文（重轉 render 產物時）——兩種都收。
        var = varmap.get(name, name)
        op, val = OPS[m.group(2)], int(m.group(3))
        # `≤ N` 在劇本裡一律是前一個 `≥ N+1` 的補集 → 當 else 段處理。
        if op == "<=":
            return {"var": var, "op": ">=", "value": val + 1}, True
        return {"var": var, "op": op, "value": val}, False

    def fold_ifs(nodes: list) -> list:
        """把 `_ifmark` 之後的節點收進 if / else。支援一場多組。"""
        out, buf, cur, is_else = [], [], None, False

        def flush():
            nonlocal cur, buf, is_else
            if cur is None:
                out.extend(buf)
            else:
                node = next((n for n in out
                             if n.get("t") == "if" and n["cond"] == cur), None)
                if node is not None and is_else:
                    node["else"] = buf
                else:
                    out.append({"t": "if", "cond": cur,
                                "then": [] if is_else else buf,
                                "else": buf if is_else else []})
            buf, cur, is_else = [], None, False

        for n in nodes:
            if n.get("t") == "_ifmark":
                flush()
                cur, is_else = mark_cond(n["raw"])
                continue
            buf.append(n)
        flush()
        # 空的 then／else 會讓走訪測試的「非空分支要有停頓節點」誤判，清掉
        for n in out:
            if n.get("t") == "if":
                for k in ("then", "else"):
                    if not n.get(k):
                        n[k] = []
        return out

    scenes = {}
    for sid, sc in sk["scenes"].items():
        sc.pop("_bg", None)
        sc["nodes"] = fix(sc["nodes"])
        if any(n.get("t") == "_ifmark" for n in sc["nodes"]):
            sc["nodes"] = fold_ifs(sc["nodes"])
        sc["background"] = spec["bg"].get(sid, list(spec["backgrounds"])[0])
        sc["bgm"] = spec.get("bgm", {}).get(sid, spec.get("bgm_default", "quiet"))
        if sc.get("isEnding"):
            sc["title"] = "結局 %s｜%s" % (sc["endingId"],
                                          spec["endings"][sc["endingId"]][0])
        scenes[sid] = sc

    # 最後一個非結局場：接上結局判定
    last = [s for s in sk["_order"] if not scenes[s].get("isEnding")][-1]
    scenes[last].pop("next", None)
    if not any(n.get("t") == "choice" and any(o.get("goto") for o in n["options"])
               for n in scenes[last]["nodes"]):
        branch = []
        for cond, target in spec["resolve"]:
            branch.append({"goto": target} if cond is None
                          else {"cond": cond, "goto": target})
            if cond is None:
                branch[-1]["default"] = True

        # 🔑 優先把判定掛到**該場既有的最後一個選擇**上，而不是另外長一個
        # 只有「……」一個選項的假選擇。
        #
        # 引擎契約（story_player.dart 的 choose）：`then` 非空就進 then，
        # `branch` 不會執行。所以掛之前要把 then 的旁白搬走——搬到目標結局場
        # 的開頭是不對的（三個結局共用同一個 branch），因此改成**併進選項文字
        # 之前的旁白節點**，效果一樣而且不需要動結局。
        tail = scenes[last]["nodes"]
        idx = next((i for i in range(len(tail) - 1, -1, -1)
                    if tail[i].get("t") == "choice"), None)
        if idx is not None and not any(o.get("then") for o in tail[idx]["options"]):
            for o in tail[idx]["options"]:
                o["branch"] = branch
        else:
            scenes[last]["nodes"].append(
                {"t": "choice", "options": [{"text": "……", "branch": branch}]})

    return {
        "schemaVersion": 1,
        "meta": {**{k: v for k, v in spec["meta"].items() if k != "minutes"},
                 "pack": "versailles_1789",
                 "estimatedMinutes": spec["meta"]["minutes"], "locale": "zh-Hant"},
        "variables": {en: {"label": lab, "initial": 0, "min": 0, "max": 4}
                      for en, lab in spec["vars"].values()},
        "characters": {key: {"name": name, **({"isPlayer": True} if player else {}),
                             "sprites": None}
                       for key, name, player, _ in spec["chars"].values()},
        "backgrounds": spec["backgrounds"],
        "missingAssets": MISSING_AUDIO + (
            [{"type": "cg", "ids": sorted(cgs),
              "note": "全螢幕標點，尚未繪製；引擎對缺件的 cg 回 null 不會崩"}]
            if cgs else []),
        "start": sk["_order"][0],
        "scenes": scenes,
        "endings": {k: {"title": t, "note": n}
                    for k, (t, n) in spec["endings"].items()},
    }


if __name__ == "__main__":
    targets = sys.argv[1:] or sorted(SPEC)
    for folder in targets:
        story = build(folder)
        out = ROOT / "stories" / folder / "story.json"
        out.write_text(json.dumps(story, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
        nodes = sum(len(s["nodes"]) for s in story["scenes"].values())
        print("%-16s 場 %d｜節點 %d" % (folder, len(story["scenes"]), nodes))
