#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""story.json 的驗證器與劇本轉檔工具。

用法:
    python3 story_tool.py check  <故事資料夾>   # 驗證
    python3 story_tool.py render <故事資料夾>   # 由 story.json 產生 script.md

設計原則：story.json 是唯一來源，script.md 一律由它產生，兩者不會 drift。
"""
import json, os, sys

MAXLEN = 60


def walk(nodes, path, out):
    for i, n in enumerate(nodes):
        p = path + [str(i)]
        out.append((n, p))
        for key in ("then", "else"):
            if isinstance(n.get(key), list):
                walk(n[key], p + [key], out)
        if n.get("t") == "choice":
            for j, o in enumerate(n.get("options", [])):
                out.append(({"t": "_opt", "text": o.get("text", "")}, p + ["opt", str(j)]))
                if isinstance(o.get("then"), list):
                    walk(o["then"], p + ["opt", str(j)], out)


def load(folder):
    with open(os.path.join(folder, "story.json"), encoding="utf-8") as f:
        return json.load(f)


def check(folder):
    d = load(folder)
    errs, warns = [], []
    scenes = d.get("scenes", {})

    flat = []
    for sid, sc in scenes.items():
        acc = []
        walk(sc.get("nodes", []), [sid], acc)
        flat += acc

    # 1. 節點字數
    for n, p in flat:
        t = n.get("text")
        if t and len(t) > MAXLEN:
            errs.append("節點過長 %d 字 (上限 %d): %s" % (len(t), MAXLEN, "#".join(p)))

    # 2. 資產參照
    for key, sub in (("backgrounds", "backgrounds"),):
        for k, fn in d.get(key, {}).items():
            if not os.path.exists(os.path.join(folder, "assets", sub, fn)):
                warns.append("背景檔不存在: %s" % fn)
    for cid, c in d.get("characters", {}).items():
        for exp, fn in (c.get("sprites") or {}).items():
            if not os.path.exists(os.path.join(folder, "assets", "sprites", fn)):
                warns.append("立繪檔不存在: %s (%s.%s)" % (fn, cid, exp))

    # 3. 場景 background / 角色 who 是否已宣告
    for sid, sc in scenes.items():
        if sc.get("background") and sc["background"] not in d.get("backgrounds", {}):
            errs.append("%s 的 background 未宣告: %s" % (sid, sc["background"]))
    for n, p in flat:
        w = n.get("who")
        if w and w not in d.get("characters", {}):
            errs.append("未宣告的角色 %s @ %s" % (w, "#".join(p)))

    # 4. 跳轉目標存在
    targets = set()
    for sid, sc in scenes.items():
        if sc.get("next"):
            targets.add((sid, sc["next"]))
    for n, p in flat:
        for g in ([n["goto"]] if n.get("goto") else []):
            targets.add(("#".join(p), g))
        if n.get("t") == "choice":
            for o in n.get("options", []):
                if o.get("goto"):
                    targets.add(("#".join(p), o["goto"]))
                for r in o.get("branch", []):
                    if r.get("goto"):
                        targets.add(("#".join(p), r["goto"]))
    for src, tgt in targets:
        if tgt not in scenes:
            errs.append("跳轉目標不存在: %s -> %s" % (src, tgt))

    # 5. 結局可達
    reachable = set()
    for sid, sc in scenes.items():
        if sc.get("next"):
            reachable.add(sc["next"])
        acc = []
        walk(sc.get("nodes", []), [sid], acc)
        for n, _ in acc:
            if n.get("goto"):
                reachable.add(n["goto"])
            if n.get("t") == "choice":
                for o in n.get("options", []):
                    if o.get("goto"):
                        reachable.add(o["goto"])
                    for r in o.get("branch", []):
                        if r.get("goto"):
                            reachable.add(r["goto"])
    for sid, sc in scenes.items():
        if sc.get("isEnding") and sid not in reachable:
            errs.append("結局不可達: %s" % sid)
    for eid in d.get("endings", {}):
        if not any(s.get("endingId") == eid for s in scenes.values()):
            warns.append("endings 宣告了 %s 但沒有對應場景" % eid)

    # 6. 統計
    texts = [n["text"] for n, _ in flat if n.get("text")]
    stats = {
        "場景": len(scenes),
        "節點": len(flat),
        "字數": sum(len(t) for t in texts),
        "最長節點": max((len(t) for t in texts), default=0),
        "選擇點": sum(1 for n, _ in flat if n.get("t") == "choice"),
        "結局": sum(1 for s in scenes.values() if s.get("isEnding")),
    }
    return errs, warns, stats


def render(folder):
    d = load(folder)
    chars = d.get("characters", {})
    tags = ["lorescape", "visual-novel"]
    pack = d["meta"].get("pack", "")          # 例：pompeii_79 → 景點標籤 pompeii
    if pack:
        tags.append(pack.split("_")[0])
    L = ["---",
         "title: %s（劇本）" % d["meta"]["title"],
         "tags:\n" + "\n".join("  - %s" % t for t in tags),
         "status: generated",
         "---", "",
         "# %s" % d["meta"]["title"], "",
         "> ⚠️ **本檔由 `story.json` 自動產生，請勿手改。**",
         "> 修改劇本請改 `story.json`，再跑 `python3 製作規範/story_tool.py render <故事資料夾>`（於 `project/lorescape/` 下執行）。", ""]

    def emit(nodes, depth):
        pad = "　" * depth
        for n in nodes:
            t = n.get("t")
            if t == "n":
                L.append("%s%s" % (pad, n["text"]))
                L.append("")
            elif t == "d":
                who = chars.get(n["who"], {}).get("name", n["who"])
                sp = "（%s）" % n["sprite"] if n.get("sprite") else ""
                L.append("%s**%s**%s：「%s」" % (pad, who, sp, n["text"]))
                L.append("")
            elif t in ("show", "hide"):
                who = chars.get(n.get("who", ""), {}).get("name", n.get("who", ""))
                L.append("%s`[%s %s %s]`" % (pad, t, who, n.get("sprite", "")))
                L.append("")
            elif t in ("sfx", "bgm", "cg"):
                L.append("%s`[%s: %s]`" % (pad, t, n.get("id")))
                L.append("")
            elif t in ("add", "set"):
                L.append("%s`[%s %s]`" % (pad, t, json.dumps(n.get("vars", {}), ensure_ascii=False)))
                L.append("")
            elif t == "if":
                c = n["cond"]
                L.append("%s`IF %s %s %s`" % (pad, c["var"], c["op"], c["value"]))
                L.append("")
                emit(n.get("then", []), depth + 1)
                if n.get("else"):
                    L.append("%s`ELSE`" % pad)
                    L.append("")
                    emit(n["else"], depth + 1)
            elif t == "choice":
                L.append("%s**▶ 選擇**" % pad)
                L.append("")
                for i, o in enumerate(n["options"], 1):
                    bits = []
                    for k in ("add", "set"):
                        if o.get(k):
                            bits.append("%s %s" % (k, json.dumps(o[k], ensure_ascii=False)))
                    if o.get("cond"):
                        c = o["cond"]
                        bits.append("需 %s %s %s" % (c["var"], c["op"], c["value"]))
                    if o.get("goto"):
                        bits.append("→ %s" % o["goto"])
                    tag = "　`%s`" % "，".join(bits) if bits else ""
                    L.append("%s　%d. %s%s" % (pad, i, o["text"], tag))
                    L.append("")
                    if o.get("then"):
                        emit(o["then"], depth + 1)

    for sid, sc in d["scenes"].items():
        L.append("---")
        L.append("")
        L.append("## %s｜%s" % (sid, sc.get("title", "")))
        L.append("")
        L.append("`BG: %s`　`BGM: %s`" % (sc.get("background"), sc.get("bgm")))
        L.append("")
        emit(sc.get("nodes", []), 0)
        if sc.get("next"):
            L.append("`→ %s`" % sc["next"])
            L.append("")

    with open(os.path.join(folder, "script.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    return os.path.join(folder, "script.md")


if __name__ == "__main__":
    cmd, folder = sys.argv[1], sys.argv[2]
    if cmd == "check":
        e, w, s = check(folder)
        print("  ".join("%s=%s" % kv for kv in s.items()))
        for x in w:
            print("⚠️  %s" % x)
        for x in e:
            print("❌ %s" % x)
        print("✅ 通過" if not e else "❌ %d 項錯誤" % len(e))
        sys.exit(1 if e else 0)
    elif cmd == "render":
        print("已產生 %s" % render(folder))
