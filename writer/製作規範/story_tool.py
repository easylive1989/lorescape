#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""story.json 的驗證器與劇本轉檔工具。

用法:
    python3 story_tool.py check  <故事資料夾>   # 驗證
    python3 story_tool.py render <故事資料夾>   # 由 story.json 產生 script.md

設計原則：story.json 是唯一來源，script.md 一律由它產生，兩者不會 drift。

check 除了結構驗證，另跑兩個語意 lint（[[劇本矛盾檢查規範]] §7）：
  1. 變數 lint     —— 空轉變數、假選項（add 0）、恆真／恆假的門檻
  2. 結局前提 lint —— 節點上的 assumes 標註，在所有可達路徑上是否成立
兩者都建立在窮舉路徑上（見 enumerate_paths）。
"""
import json, os, sys, collections

MAXLEN = 60
MAXPATHS = 50000        # 路徑爆炸時的保險絲；超過就跳過語意 lint 並警告


# ── 窮舉直譯器 ────────────────────────────────────────────────────
#
# 引擎語意（story_player.dart）：
#   - 場景節點依序執行，走完接 scene.next；isEnding 的場景走完即結束
#   - if 依 cond 走 then／else，走完回到 if 之後的節點
#   - choice 的選項：有 then 就進 then（走完接續同場剩餘節點），
#     否則看 goto／branch 跳場
# 這裡把所有選項都走一遍，得到每條路徑的變數終值、選擇序列與命中紀錄。

def _ev(c, v):
    a, op, b = v.get(c["var"]), c["op"], c["value"]
    if op == "==": return a == b
    if op == "!=": return a != b
    if op == ">=": return (a if isinstance(a, int) else 0) >= b
    if op == "<=": return (a if isinstance(a, int) else 0) <= b
    if op == ">":  return (a if isinstance(a, int) else 0) > b
    if op == "<":  return (a if isinstance(a, int) else 0) < b
    raise ValueError("未知的比較運算子: %s" % op)


def _apply(add, st, v):
    v = dict(v)
    for k, x in (add or {}).items():
        v[k] = (v.get(k) or 0) + x
    for k, x in (st or {}).items():
        v[k] = x
    return v


def enumerate_paths(d):
    """回傳 (paths, ifhits, violations, overflow)。

    paths      —— [(picks, vars, endingId)]
    ifhits     —— Counter[(場景|條件字串, 命中真假)]
    violations —— [(場景, 節點文字, 變數, 期望, 實際, 選擇序列)]
    """
    scenes = d["scenes"]
    out = {"paths": [], "ifhits": collections.Counter(), "viol": [], "over": False}

    def record(v, picks, sc):
        if len(out["paths"]) >= MAXPATHS:
            out["over"] = True
            return
        out["paths"].append((tuple(picks), v, sc.get("endingId") or "＜非結局＞"))

    def run_scene(sid, v, picks):
        if out["over"]:
            return
        sc = scenes[sid]

        def after(v2, picks2):
            if sc.get("isEnding") or not sc.get("next"):
                record(v2, picks2, sc)
            else:
                run_scene(sc["next"], v2, picks2)

        run_nodes(sc.get("nodes", []), 0, v, picks, sid, after)

    def run_nodes(nodes, i, v, picks, sid, k):
        while i < len(nodes):
            if out["over"]:
                return
            nd, t = nodes[i], nodes[i].get("t")

            for var, want in (nd.get("assumes") or {}).items():
                if v.get(var) != want:
                    out["viol"].append((sid, (nd.get("text") or "")[:24],
                                        var, want, v.get(var), tuple(picks)))

            if t == "add":
                v = _apply(nd.get("vars"), None, v)
            elif t == "set":
                v = _apply(None, nd.get("vars"), v)
            elif t == "if":
                hit = _ev(nd["cond"], v)
                c = nd["cond"]
                out["ifhits"][("%s|%s %s %s" % (sid, c["var"], c["op"], c["value"]), hit)] += 1
                br = nd.get("then") if hit else (nd.get("else") or [])
                rest, ri = nodes, i + 1
                return run_nodes(br, 0, v, picks, sid,
                                 lambda v2, p2: run_nodes(rest, ri, v2, p2, sid, k))
            elif t == "choice":
                rest, ri = nodes, i + 1
                for j, o in enumerate(nd.get("options", [])):
                    if o.get("cond") and not _ev(o["cond"], v):
                        continue
                    v2 = _apply(o.get("add"), o.get("set"), v)
                    p2 = picks + ["%s.%d" % (sid, j + 1)]
                    if o.get("then"):
                        run_nodes(o["then"], 0, v2, p2, sid,
                                  lambda v3, p3: run_nodes(rest, ri, v3, p3, sid, k))
                    elif o.get("goto"):
                        run_scene(o["goto"], v2, p2)
                    elif o.get("branch"):
                        for b in o["branch"]:
                            if b.get("default") or _ev(b["cond"], v2):
                                run_scene(b["goto"], v2, p2)
                                break
                    else:
                        run_nodes(rest, ri, v2, p2, sid, k)
                return
            if nd.get("goto") and t != "choice":
                return run_scene(nd["goto"], v, picks)
            i += 1
        return k(v, picks)

    run_scene(d["start"], {}, [])
    return out["paths"], out["ifhits"], out["viol"], out["over"]


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

    # 1.5 選項的 then 與 goto／branch 互斥
    #
    # 引擎契約（story_player.dart 的 choose()）：**option.then 非空時就進 then，
    # goto／branch 完全不會被執行**。兩者同時給，跳轉會被靜默吃掉，然後在場尾
    # 炸「走到底但既沒有 next 也不是結局」——而且只有實際跑引擎才炸得出來。
    # 凡爾賽第一篇踩過一次，所以搬到這裡擋。
    for sid, sc in scenes.items():
        acc = []
        walk(sc.get("nodes", []), [sid], acc)
        for n, p in acc:
            if n.get("t") != "choice":
                continue
            for j, o in enumerate(n.get("options", [])):
                if o.get("then") and (o.get("goto") or o.get("branch")):
                    errs.append(
                        "選項同時有 then 與 goto/branch，跳轉會被引擎忽略: %s#opt%d"
                        % ("#".join(p), j))

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

    # 6. 語意 lint（規範 §7）。結構有錯時路徑走不通，先不跑。
    npaths = 0
    if not errs:
        try:
            paths, ifhits, viol, over = enumerate_paths(d)
        except Exception as e:                      # 直譯器踩到未支援的語法就別擋人
            warns.append("語意 lint 跳過（%s: %s）" % (type(e).__name__, e))
        else:
            npaths = len(paths)
            if over:
                warns.append("路徑數超過 %d，語意 lint 只跑了前 %d 條，結果不完整"
                             % (MAXPATHS, MAXPATHS))

            # 6a. 變數 lint
            written, read = set(), set()
            for n, p in flat:
                if n.get("t") in ("add", "set"):
                    written |= set((n.get("vars") or {}).keys())
                if n.get("t") == "add":
                    for k, x in (n.get("vars") or {}).items():
                        if x == 0:
                            errs.append("add 值為 0，這個寫入沒有作用: %s (%s)"
                                        % ("#".join(p), k))
                for c in ([n["cond"]] if n.get("cond") else []):
                    read.add(c["var"])
            for sid, sc in scenes.items():
                acc = []
                walk(sc.get("nodes", []), [sid], acc)
                for n, p in acc:
                    if n.get("t") != "choice":
                        continue
                    for j, o in enumerate(n.get("options", [])):
                        written |= set((o.get("add") or {}).keys())
                        written |= set((o.get("set") or {}).keys())
                        for k, x in (o.get("add") or {}).items():
                            if x == 0:
                                errs.append("選項的 add 值為 0，這是個假選項: %s#opt%d (%s)"
                                            % ("#".join(p), j, k))
                        if o.get("cond"):
                            read.add(o["cond"]["var"])
                        for b in o.get("branch", []):
                            if b.get("cond"):
                                read.add(b["cond"]["var"])

            for k in sorted(written - read):
                warns.append("空轉變數：%s 有寫入但從來沒有人讀它" % k)
            for k in sorted(read - written):
                errs.append("讀取了從未寫入的變數：%s（拼錯？）" % k)
            for k in sorted(set(d.get("variables", {})) - read):
                warns.append("variables 宣告了 %s 但沒有任何條件讀它" % k)

            for key in sorted({k for k, _ in ifhits}):
                t, f = ifhits[(key, True)], ifhits[(key, False)]
                if not f:
                    warns.append("條件恆真，else 是死碼：%s" % key)
                elif not t:
                    warns.append("條件恆假，then 讀不到：%s" % key)

            # 6b. 結局前提 lint（節點上的 assumes 標註）
            seen = set()
            for sid, txt, var, want, got, picks in viol:
                sig = (sid, txt, var)
                if sig in seen:
                    continue
                seen.add(sig)
                errs.append("assumes 不成立：%s「%s」預期 %s=%r，實際 %r（例：%s）"
                            % (sid, txt, var, want, got, " → ".join(picks)))

    # 7. 統計
    texts = [n["text"] for n, _ in flat if n.get("text")]
    stats = {
        "場景": len(scenes),
        "節點": len(flat),
        "字數": sum(len(t) for t in texts),
        "最長節點": max((len(t) for t in texts), default=0),
        "選擇點": sum(1 for n, _ in flat if n.get("t") == "choice"),
        "結局": sum(1 for s in scenes.values() if s.get("isEnding")),
        "路徑": npaths,
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
