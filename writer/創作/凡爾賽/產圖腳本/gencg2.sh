#!/bin/zsh
# 其餘七篇的全螢幕 CG（9:16）。用法: gencg2.sh <key> [<key> ...]
#
# **每篇只挑一到兩張**，不是把劇本裡每個 `FULL:` 都畫。
# 理由：全螢幕的效果來自稀有——一篇裡出現六次，它就只是換一張背景。
# 挑的標準：**這一格如果拿掉，那一篇會少掉什麼**。
#
# 相機規則同 gencg.sh：**第一人稱，主角低頭看自己或看眼前的東西**
# （第一篇_場景清單 §5.1a）。主角不做立繪，這是唯一看得到她／他身體的位置。
SELF="${0:A}"
OUT="${SELF:h}/../美術測試"

PREFIX="realistic digital matte painting, archaeological reconstruction illustration, high detail, subtle painterly finish, not photographic, late-18th-century French palette — wet pale limestone, slate blue-grey, muted gilt, rain-desaturated green, mud brown, with dull crimson as the only warm accent, overcast rain light, low contrast, muted saturation"

COMPO="Vertical 9:16 portrait composition for a mobile screen, FULL BLEED — this is a full-screen story image with no dialogue box over it, so the subject may use the whole frame including the bottom edge. Close, intimate framing. No text."

KEEP="Historically grounded France, October 1789. Everything visible is wool, linen, leather, wood, stone, iron, brass or wax. No machine stitching, no rubber, no plastic, no printed fabric, no gas light."

NEG="anime, cel shading, glossy, neon, oversaturated, modern objects, plastic, printed fabric, gas lamps, electric light, text watermark, signature, lettering, faces"

case "$1" in
# ── 1️⃣ 擋板：空的木架 ────────────────────────────────────────────────
# 全篇的支點。他站在檯子這一邊，而架子上什麼都沒有了。
shelf) F="cg_01_shelf"; S="THE SUBJECT IS THE EMPTY BREAD SHELF OF A PARIS BAKERY, seen from BEHIND the counter — the baker's own view, looking out. Bare scrubbed wooden shelving, four levels, completely empty except for loose crumbs and a scatter of flour in the corners of each board; the wood is worn pale and smooth in the places where loaves have sat for decades. In the foreground the edge of the counter, a set of iron scales with both pans empty, and a pair of floury forearms resting on the wood. Beyond the counter, out of focus, the daylight of an open shutter and the shapes of people still waiting.";;

# ── 3️⃣ 柵欄的兩邊：門外坐下來的人群 ─────────────────────────────────
# 他一整個下午都在等他們走。他們沒有走，他們坐下來了。
staying) F="cg_03_staying"; S="THE SUBJECT IS A CROWD SETTLING DOWN TO STAY THE NIGHT OUTSIDE A PALACE GATE IN THE RAIN, seen from INSIDE the railing looking out through the bars, at eye level. Beyond the black iron bars: dozens of small guttering fires on wet ground, people sitting and lying against each other with shawls pulled over their heads, bundles and baskets used as pillows, a shoe left off to dry by a fire. The nearest figures are close enough to see the water running off their shawls. Nobody is standing. Nobody is leaving. Cold night, thin rain, firelight the only warm colour.";;

# ── 4️⃣ 三天份的行李：扣好的箱子 ─────────────────────────────────────
# 全篇的機關。一個箱子裡放了什麼，就是這座宮殿對自己處境的真實判斷。
trunk) F="cg_04_trunk"; S="THE SUBJECT IS A LEATHER-AND-WOOD TRAVELLING TRUNK, CLOSED AND STRAPPED, standing alone on a polished parquet floor by candlelight, seen from close and slightly above as if the person who packed it is still standing over it. Two leather straps buckled tight across the lid — one of them visibly tighter than the other, re-done. Brass corner fittings and a heavy lock. The trunk is OBVIOUSLY TOO LARGE for three days, and it sits low as though heavily loaded. A single candle on the floor beside it throws a long shadow. Everything beyond the candle is darkness.";;

# ── 5️⃣ 陽台：仰角 ───────────────────────────────────────────────────
# 全包情緒最高的一格，而它的力量來自看不清楚。
balcony) F="cg_05_balcony"; S="THE SUBJECT IS A FIRST-FLOOR BALCONY SEEN FROM DIRECTLY BELOW IN A CROWDED COURTYARD, LOOKING STEEPLY UP AGAINST A PALE GREY MORNING SKY. A gilded wrought-iron balcony rail runs across the frame; above and behind it, standing figures reduced to DARK SILHOUETTES against the bright sky — features completely lost to the backlight, only shapes, one taller than the others. Wet stone and tall windows around them. In the very bottom of the frame, out of focus, the tops of hundreds of hats and heads. The viewer is far below and cannot see anything clearly. NO FACES ARE LEGIBLE.";;

# ── 6️⃣ 牛奶：三桶 ───────────────────────────────────────────────────
# 全包的主題在這一格合攏：假農村裡唯一真的牛奶，沒有人要。
milk) F="cg_06_milk"; S="THE SUBJECT IS THREE FULL WOODEN MILK PAILS standing side by side on a stone dairy floor, seen from close and above. Coopered oak pails with iron hoops and rope handles, filled to within an inch of the rim with fresh milk; a skin has begun to form on the surface of two of them, and one has a fly on it. The stone floor is swept clean and wet. Cold pale light from a small high window. Nothing else in the frame — no people, no hands. The milk is perfectly still and perfectly good and nobody has come for it.";;

# ── 7️⃣ 麵包師傅一家：鞋帶上的兩個結 ─────────────────────────────────
# 母親身分的唯一線索。玩家在 2️⃣ 看過同一個動作。
knots) F="cg_07_knots"; S="THE SUBJECT IS A CHILD'S SHOE BEING UNTIED BY LAMPLIGHT, seen from directly above and very close as the child looks down at his own foot. A worn brown leather shoe, CLEARLY TOO LARGE for the foot in it, caked with dried mud; the lace is tied in TWO KNOTS ONE ON TOP OF THE OTHER, pulled tight and swollen with water so they cannot be picked apart. Small chapped fingers are working at the knots without success. A thick undyed wool stocking, muddy. Warm low lamplight from one side, everything else dark.";;

# ── 8️⃣ 今晚不點了：全部點著的宮殿走廊 ──────────────────────────────
# 全包最後一格。這是它最後一次亮成這樣。
lastlight) F="cg_08_lastlight"; S="THE SUBJECT IS A LONG PALACE GALLERY WITH EVERY CANDLE LIT, seen down its length from one end at night — and completely empty of people. Rows of gilded wall-sconces down both sides, every one burning; tall arched mirrors repeating the flames again and again into the distance; a polished parquet floor reflecting the whole length of it. The light is warm, even and generous, and there is absolutely nobody to see it. In the very foreground, out of focus at the bottom edge, the top of a brass candlestick held low in one hand.";;

*) echo "unknown key: $1"; echo "可用: shelf staying trunk balcony milk knots lastlight"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write \
  "Use your image_gen tool to generate one image, aspect ratio 9:16 portrait. ${PREFIX}. ${S} ${COMPO} ${KEEP} Avoid: ${NEG}. Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -2

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
