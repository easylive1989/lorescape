#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""凡爾賽景點包的內容守門。跑法：`python3 lint_content.py`

`story_tool.py check` 驗的是**結構**（節點長度、跳轉、資產、可達性）；
這支驗的是**內容**——那些寫壞了不會報錯、但整個包就毀了的東西。

三道檢查，全部來自本包已經寫死的規則：

1. **反君主制與時代錯置**（凡爾賽史實紅線 §3 約束 2、§4）
   1789/10 幾乎無人主張廢除君主制；斷頭台、紅帽、「公民」、法郎、公制、
   指券全都在時間窗之後。**這是本包最嚴重的一類錯，而且直覺完全擋不住**——
   因為它們是「同一場革命」的東西，只是晚了三到五年。

2. **「之後」段不得出現評價字眼**（凡爾賽命題 §3）
   每個結局的「之後」只能陳述事實。寫成道德判決，整個延遲後果的機制就毀了。
   檢查方式就是命題裡那句：**這段話有沒有告訴玩家他選錯了？**

3. **疑似轉檔遺失**
   以「：」或「——」結尾卻沒有下文的節點。**這條是實際踩過的**：轉檔工具
   原本把 markdown 引用區塊整段丟掉，而 7️⃣ 的那句群眾口號——全包的酬載、
   篇名的由來——就寫在引用區塊裡，靜默消失，只剩「他們在喊：」接
   「喊完大家就笑」。根因已修（md2story.py 保留含「」的引用行），
   這道掃描留著當網。
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

FORBIDDEN = {
    "反君主制": ["共和", "廢除君主", "推翻國王", "打倒國王", "革命份子"],
    "革命式稱謂": ["公民", "citoyen", "雅各賓", "無套褲"],
    "晚三到五年的符號": ["斷頭台", "弗里吉亞", "紅帽", "自由平等博愛"],
    "度量與貨幣": ["法郎", "公尺", "公斤", "指券"],
    "物質錯置": ["馬鈴薯", "番茄", "玉米", "瓦斯燈"],
}
JUDGEMENT = ["應該", "後悔", "錯了", "對的選擇", "錯誤", "值得", "不值得",
             "活該", "可惜", "幸好", "還好", "如果當初", "本來可以",
             "早知道", "遺憾"]


def all_text(story, endings_only=False):
    """(場 id, 文字) — 走遍 then／else／choice option 的每一段。"""
    for sid, sc in story["scenes"].items():
        if endings_only and not sc.get("isEnding"):
            continue

        def walk(nodes):
            for n in nodes:
                if n.get("text"):
                    yield n["text"]
                for k in ("then", "else"):
                    if isinstance(n.get(k), list):
                        yield from walk(n[k])
                if n.get("t") == "choice":
                    for o in n["options"]:
                        if o.get("text"):
                            yield o["text"]
                        if isinstance(o.get("then"), list):
                            yield from walk(o["then"])

        for t in walk(sc["nodes"]):
            yield sid, t


def dangling(story):
    """以「：」「——」結尾但下一句不像接續的節點。"""
    out = []
    for sid, sc in story["scenes"].items():
        def walk(nodes):
            for i, n in enumerate(nodes):
                t = n.get("text", "")
                if t.endswith(("：", "——", ":")):
                    nxt = nodes[i + 1].get("text", "") if i + 1 < len(nodes) else ""
                    out.append((sid, t, nxt))
                for k in ("then", "else"):
                    if isinstance(n.get(k), list):
                        walk(n[k])
                if n.get("t") == "choice":
                    for o in n["options"]:
                        if isinstance(o.get("then"), list):
                            walk(o["then"])
        walk(sc["nodes"])
    return out


def main() -> int:
    errs, warns = [], []
    for d in sorted((ROOT / "stories").iterdir()):
        sj = d / "story.json"
        if not sj.exists():
            continue
        story = json.loads(sj.read_text(encoding="utf-8"))

        for sid, t in all_text(story):
            for label, words in FORBIDDEN.items():
                for w in words:
                    if w in t:
                        errs.append(f"{d.name}/{sid} [{label}:{w}] {t}")

        for sid, t in all_text(story, endings_only=True):
            for w in JUDGEMENT:
                if w in t:
                    errs.append(f"{d.name}/{sid} [「之後」有評價字眼:{w}] {t}")

        for sid, t, nxt in dangling(story):
            warns.append(f"{d.name}/{sid} 「{t}」→「{nxt[:20]}」")

    for e in errs:
        print("✗", e)
    if warns:
        print(f"\n⚠️ {len(warns)} 處以「：」或「——」結尾，人工確認下文有接上：")
        for w in warns:
            print("  ", w)
    if errs:
        print(f"\n✗ {len(errs)} 個內容錯誤")
        return 1
    print(f"\n✅ 內容檢查通過（{len(warns)} 處待人工確認的接續）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
