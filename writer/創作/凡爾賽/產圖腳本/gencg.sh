#!/bin/zsh
# 〈二十公里〉的 6 張全螢幕 CG（9:16）。用法: gencg.sh <key> [<key> ...]
#
# 這些跟背景不是同一種東西，構圖規則也不同：
#   背景  → 下方 35% 要留給對話框，主體基部落在 60% 高度
#   CG    → 關掉對話框、關掉立繪，整個畫面都是它的（產品規格書 §5.3）
# 所以 COMPO 不沿用 genbg.sh 的那一套，改成滿版構圖。
#
# 🔑 相機一律是「主角低頭看自己」。主角第一人稱、不做立繪，這些 CG 是
# 全篇唯一看得到她身體的地方——鞋子那條敘事主軸就靠它們（第一篇_場景清單 §5）。
SELF="${0:A}"
OUT="${SELF:h}/../美術測試"

# 與 genbg.sh 同一組風格與色票，一字不改——CG 和背景在同一個畫面裡交替出現，
# 色調對不上會立刻看出是兩批圖。
PREFIX="realistic digital matte painting, archaeological reconstruction illustration, high detail, subtle painterly finish, not photographic, late-18th-century French palette — wet pale limestone, slate blue-grey, muted gilt, rain-desaturated green, mud brown, with dull crimson as the only warm accent, overcast rain light, low contrast, muted saturation"

COMPO="Vertical 9:16 portrait composition for a mobile screen, FULL BLEED — this is a full-screen story image with no dialogue box over it, so the subject may use the whole frame including the bottom edge. Close, intimate framing. Shallow depth of scene. No text."

KEEP="Historically grounded France, October 1789. Everything visible is wool, linen, leather, wood, stone or mud. No machine stitching, no rubber, no plastic, no printed fabric."

NEG="anime, cel shading, glossy, neon, oversaturated, modern shoes, rubber soles, sneakers, boots with laces through metal eyelets, zips, plastic, printed fabric, text watermark, signature, lettering, people's faces"

case "$1" in
# ── S01：魚在，麵包不在 ───────────────────────────────────────────────
# 出圖時抓到的那個修正（第一篇_場景清單 §4.1）：她有東西賣，只是換不到麵包。
fish) F="cg_fish"; S="THE SUBJECT IS A FISHMONGER'S STONE SLAB AT DAYBREAK, seen from directly above and close, as if the viewer is standing at the stall looking down at her own goods. The worn grey stone is covered edge to edge with fresh river fish, laid in overlapping rows, wet and silver-grey, their scales catching the low warm light of a single oil lantern hanging just out of frame above. Melting ice and water run off the front edge of the slab. A pair of red chapped human hands rests at the bottom edge of the frame, palms down on the stone. The slab is FULL. Everything else is in cold blue pre-dawn shadow.";;

# ── S03：鞋 ①（乾的）─────────────────────────────────────────────────
shoe_dry) F="cg_shoe_dry"; S="THE SUBJECT IS A PAIR OF WOMAN'S SHOES SEEN FROM ABOVE, as if she is standing still and looking down at her own feet. Plain black leather shoes with a low stacked heel and a small dull pewter buckle over the instep, an ankle-length brown wool petticoat hem just entering the top of the frame, coarse pale wool stockings. The leather is worn but SOUND, the seams intact, the surface DRY and only just dusted with street grit. They stand on wet grey cobblestones at first light. Cold blue morning light. This is a woman who has not yet walked anywhere today.";;

# ── S04：鞋 ②（濕透）────────────────────────────────────────────────
shoe_wet) F="cg_shoe_wet"; S="THE SUBJECT IS THE SAME PAIR OF WOMAN'S SHOES SEEN FROM ABOVE, mid-stride on a churned unpaved road, as if she is looking down while still walking. The same black leather shoes with dull pewter buckles, now DARK AND SATURATED with water, sunk to the welt in soft brown mud, mud splashed up over the buckles and onto the pale wool stockings; the petticoat hem at the top of the frame is soaked heavy and hanging crooked. Water stands in the ruts around them and rain is falling, breaking the surface of every puddle. Flat grey overcast light.";;

# ── S06：鞋 ③（壞掉）────────────────────────────────────────────────
# 綁的那條布是從她自己的圍裙撕下來的——劇本裡寫死的動作，圖要對得上。
shoe_broken) F="cg_shoe_broken"; S="THE SUBJECT IS THE SAME PAIR OF WOMAN'S SHOES SEEN FROM ABOVE, standing still in deep mud. The LEFT shoe is intact. The RIGHT shoe has SPLIT OPEN along the outer side where the upper meets the sole, the leather gaping to show the wet stocking inside, and it has been BOUND SHUT with a torn strip of coarse undyed apron cloth wound twice around the whole shoe and knotted on top — the knot is clumsy, tied in a hurry by cold hands. The cloth is already soaked brown. Rain still falling. Flat grey light.";;

# ── E-A / E-B / E-C：鞋 ④（停下）────────────────────────────────────
# 一張給三個結局共用。**站定不動**是全部的內容——A 與 B 的差別在引擎那層用
# 前後景處理，不重畫（第一篇_場景清單 §5.1）。
shoe_still) F="cg_shoe_still"; S="THE SUBJECT IS THE SAME PAIR OF WOMAN'S SHOES SEEN FROM ABOVE, STANDING COMPLETELY STILL. Both feet flat, side by side, weight settled evenly — not mid-step, not shifting. The right shoe is still bound with its soaked strip of apron cloth, the knot on top. They stand in shallow standing water on old grey paving, and the water is perfectly undisturbed around them, reflecting a colourless evening sky. The rain has stopped. The mud on the leather has begun to dry pale at the edges. Nothing in the frame is moving.";;

# ── S07：關著的門 ───────────────────────────────────────────────────
# 與 bg_palace_gate 刻意不同構圖：那張有天空、有前庭、有景深；
# 這張只有門，滿版，讓「走了一整天，然後呢」那一格沒有別的東西可看。
gate_shut) F="cg_gate_shut"; S="THE SUBJECT IS A TALL WROUGHT-IRON PALACE GATE, SHUT, seen straight on from very close and FILLING THE ENTIRE FRAME edge to edge — no sky, no ground, no surrounding architecture, just the iron. Close-set vertical black bars, a heavy horizontal rail, and gilded ornament at the joints with the gilding dulled and streaked, rainwater running down every bar and beading along the underside of the rail. Through the bars, far behind and thrown completely out of focus, an empty pale paved courtyard streaming with water. The gate is the only thing in focus. Cold grey rain light.";;

*) echo "unknown key: $1"; echo "可用: fish shoe_dry shoe_wet shoe_broken shoe_still gate_shut"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write \
  "Use your image_gen tool to generate one image, aspect ratio 9:16 portrait. ${PREFIX}. ${S} ${COMPO} ${KEEP} Avoid: ${NEG}. Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -2

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
