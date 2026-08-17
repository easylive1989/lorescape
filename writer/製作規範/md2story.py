#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把手寫劇本 markdown 轉成 story.json 的骨架。

用法:
    python3 md2story.py <script.md>          # 印出 JSON
    python3 md2story.py <script.md> -o <dir> # 寫進 <dir>/story.json

**這支工具只做機械的部分**：切場、切節點、把長句拆到 60 字以內、認出
`BG:` `SFX:` `FULL:` `立繪:` 與對白。變數、選項的 add/goto、結局判定
一律**不猜**——那些是設計，猜錯了會靜默壞掉。轉完必須人工補齊並跑
`story_tool.py check`。

為什麼需要它：一篇 5,000 字的劇本手工切成 350 個 ≤60 字的節點，是純機械
勞動而且必然出錯（第一篇轉檔時就漏過 `then` 與 `goto` 互斥）。機械的部分
交給程式，人只處理設計。
"""
import json, re, sys, pathlib

MAXLEN = 60

# 中文斷句點。優先在句末標點切，切不動才退而求其次找逗號。
HARD = "。！？…"
SOFT = "，、；："


def split_text(text: str) -> list[str]:
    """把一段話切成每段 ≤ MAXLEN 字。**在標點後切，不從中間硬切。**"""
    text = text.strip()
    if len(text) <= MAXLEN:
        return [text] if text else []

    out, buf = [], ""
    # 先按句末標點切成句子（保留標點）
    sentences = re.findall(r"[^%s]*[%s]|[^%s]+$" % (HARD, HARD, HARD), text)
    for sent in sentences:
        sent = sent.strip()
        if not sent:
            continue
        if len(buf) + len(sent) <= MAXLEN:
            buf += sent
            continue
        if buf:
            out.append(buf)
            buf = ""
        if len(sent) <= MAXLEN:
            buf = sent
            continue
        # 單句還是太長 → 在逗號類標點後切
        parts = re.findall(r"[^%s]*[%s]|[^%s]+$" % (SOFT, SOFT, SOFT), sent)
        cur = ""
        for part in parts:
            if len(cur) + len(part) <= MAXLEN:
                cur += part
            else:
                if cur:
                    out.append(cur)
                # 逗號也切不動就只好硬切，但這代表原文該改寫，印出警告
                while len(part) > MAXLEN:
                    print("⚠️ 無標點可切，硬切: %s" % part[:20], file=sys.stderr)
                    out.append(part[:MAXLEN])
                    part = part[MAXLEN:]
                cur = part
        if cur:
            buf = cur
    if buf:
        out.append(buf)
    return out


def parse(md: str) -> dict:
    scenes: dict[str, dict] = {}
    order: list[str] = []
    current: dict | None = None

    # 只吃 `## S01｜標題` 與 `## E-A｜標題` 這兩種場標題
    for raw in md.split("\n"):
        line = raw.rstrip()

        # 🔑 非場景的 `##` 標題（檢核、待處理…）要**關掉目前的場**。
        # 不關的話，劇本末尾的檢核表與待辦會被當成旁白，全部灌進最後一個
        # 結局場——抽驗 6️⃣ 時實際看到「字數約 4,800｜選擇點 6」印在結局裡。
        if line.startswith("## "):
            m = re.match(r"^## ([SE][\w-]*)｜(.+)$", line)
            if not m:
                current = None
                continue
        else:
            m = None
        if m:
            sid = m.group(1).replace("-", "_")
            current = {"title": m.group(2).strip(), "nodes": []}
            if sid.startswith("E_"):
                current["isEnding"] = True
                current["endingId"] = sid[2:]
            scenes[sid] = current
            order.append(sid)
            continue

        if current is None:
            continue

        # `BG: xxx` `SFX: xxx` `FULL: xxx` `立繪: xxx`（可同行多個反引號區塊）
        tags = re.findall(r"`([^`]+)`", line)
        if tags and not line.startswith(("**", "　", "▶")):
            for tag in tags:
                t = tag.strip()
                if t.startswith("BG:"):
                    current.setdefault("_bg", t[3:].strip())
                elif t.startswith("SFX:"):
                    current["nodes"].append({"t": "sfx", "id": t[4:].strip()})
                elif t.startswith("FULL:"):
                    current["nodes"].append(
                        {"t": "cg", "id": t[5:].strip(),
                         "fullscreen": True, "hideDialogue": True})
                elif t.startswith("立繪:"):
                    current["nodes"].append({"t": "show", "_who": t[3:].strip()})
                elif t.startswith("IF "):
                    # 🔑 劇本裡的 `IF 選了 S03 ①` / `IF 未選 S03 ①` 是**互斥的
                    # 兩段內容**，不是連續的兩段。不認得它就會攤平成直線，
                    # 讓同一個決定被問兩次——實測 6️⃣7️⃣ 因此各有一個結局
                    # 永遠到不了（走訪測試抓到的）。
                    current["nodes"].append({"t": "_ifmark", "raw": t[3:].strip()})
            continue

        # 對白：**名字**：「內容」
        m = re.match(r"^\*\*([^*]+)\*\*：[「\"](.*)[」\"]\s*$", line)
        if m:
            for chunk in split_text(m.group(2)):
                current["nodes"].append(
                    {"t": "d", "_who": m.group(1).strip(), "text": chunk})
            continue

        # ── 選項行 ──────────────────────────────────────────────────
        # 格式（實測全 8 篇一致）：
        #   　① **選項文字**　`→ 變數 +N`　`IF 變數 ≥ N`　「then 旁白」
        # `→ **結局 X**` 與 `→ **前往結局 C**` 也認得。
        m = re.match(r"^　[①②③④]\s*\*\*(.+?)\*\*(.*)$", line)
        if m:
            opt = {"text": m.group(1).strip(), "_raw": m.group(2).strip()}
            rest = m.group(2)
            add: dict[str, int] = {}
            for var, sign, num in re.findall(
                    r"`→\s*([^\s`+\-]+)\s*([+\-])\s*(\d+)`", rest):
                add[var] = add.get(var, 0) + (int(num) if sign == "+" else -int(num))
            if add:
                opt["_add"] = add
            g = re.search(r"→\s*\*\*(?:前往)?結局\s*([A-C])\*\*", rest)
            if g:
                opt["_goto"] = "E_" + g.group(1)
            c = re.search(r"`IF\s+(\S+)\s*([≥≤=><]+)\s*(\d+)`", rest)
            if c:
                opt["_cond"] = {"var": c.group(1), "op": c.group(2),
                                "value": int(c.group(3))}
            t = re.search(r"「(.+)」", rest)
            if t:
                opt["_then"] = split_text(t.group(1))
            # 掛在最近一個 choice 節點上；沒有就先開一個
            if not current["nodes"] or current["nodes"][-1].get("t") != "choice":
                current["nodes"].append({"t": "choice", "options": []})
            current["nodes"][-1]["options"].append(opt)
            continue

        # ── 引用區塊：**含台詞的要留，設計註解才丟** ────────────────────
        #
        # 🔴 這是實際造成內容遺失的一條。原本 `>` 開頭一律跳過，而我用引用
        # 區塊寫了 7️⃣ 的那句群眾口號——**全包的酬載、篇名的由來**——整段被
        # 靜默吃掉，轉檔後只剩「他們在喊：」接「喊完大家就笑」。
        #
        # 判準：引用區塊裡**有「」括起來的話**就是內容，其餘才是設計註解。
        if line.startswith(">"):
            inner = re.sub(r"^>+\s*", "", line)
            inner = re.sub(r"\*\*|\*", "", inner).strip()
            if "「" in inner and "」" in inner:
                for chunk in split_text(inner):
                    current["nodes"].append({"t": "n", "text": chunk})
            continue

        # 其餘設計註解一律跳過，交給人
        if line.startswith(("▶", "　", "|", "---", "#", "`")):
            continue
        if not line.strip():
            continue

        # 其餘視為旁白。去掉 markdown 強調記號。
        text = re.sub(r"\*\*|\*|~~", "", line).strip()
        if not text or text.startswith("["):
            continue
        for chunk in split_text(text):
            current["nodes"].append({"t": "n", "text": chunk})

    # 預設串成一直線，人再改 next / goto
    for i, sid in enumerate(order):
        if scenes[sid].get("isEnding"):
            continue
        nxt = next((s for s in order[i + 1:] if not scenes[s].get("isEnding")), None)
        if nxt:
            scenes[sid]["next"] = nxt

    return {"_order": order, "scenes": scenes}


if __name__ == "__main__":
    src = pathlib.Path(sys.argv[1])
    text = src.read_text(encoding="utf-8")
    # 🔒 `story_tool.py render` 產生的 script.md 不能拿來重轉。
    #
    # 這是實際踩過的坑：script.md 一度既是撰稿來源、又是 render 的產物，
    # 對 06_牛奶 跑了一次 render 就把手寫的設定表與檢核表蓋掉了。
    # **修法是把設定與檢核搬到 README.md**，script.md 從此只由 story.json 產生；
    # 這道擋門確保沒有人再把產物餵回轉檔工具。
    if "status: generated" in text[:400]:
        sys.exit("✗ %s 是 render 產生的，不是撰稿來源。"
                 "設定與檢核在同資料夾的 README.md。" % src)
    result = parse(text)
    total = sum(len(s["nodes"]) for s in result["scenes"].values())
    chars = sum(len(n.get("text", "")) for s in result["scenes"].values()
                for n in s["nodes"])
    print("場 %d｜節點 %d｜字數 %d" % (len(result["scenes"]), total, chars),
          file=sys.stderr)
    if "-o" in sys.argv:
        out = pathlib.Path(sys.argv[sys.argv.index("-o") + 1]) / "_skeleton.json"
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                       encoding="utf-8")
        print("→ %s（骨架，變數與選項待人工補）" % out, file=sys.stderr)
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
