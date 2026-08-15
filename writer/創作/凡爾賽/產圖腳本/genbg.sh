#!/bin/zsh
# 凡爾賽 1789 十月進軍：直式背景（9:16）
# 用法: genbg.sh <key> [<key> ...]
#
# 風格骨幹寫死在這裡，照 美術風格聖經 §2 的結構：
#   [風格前綴] + [主體與時代描述] + [構圖與鏡位] + [光線] + [色票] + [負面提示]
# 要改風格改這支腳本，不要臨時另寫 prompt——龐貝第 5 輪就是因為換了措辭，
# 整批立繪跑成攝影風而作廢。
SELF="${0:A}"
OUT="${SELF:h}/../美術測試"

# ── 風格前綴 ────────────────────────────────────────────────────────────
# 沿用龐貝定案的「寫實 matte painting」方向（美術風格聖經 §1 v2），但色票換掉：
# 龐貝壁畫色調是龐貝的考據結論，不是全案通則。1789 年十月的凡爾賽錨在「雨」——
# 那六千至一萬名婦女是冒雨走了二十公里到宮門口的。
PREFIX="realistic digital matte painting, archaeological reconstruction illustration, high detail, subtle painterly finish, not photographic, late-18th-century French palette — wet pale limestone, slate blue-grey, muted gilt, rain-desaturated green, mud brown, with dull crimson as the only warm accent, overcast rain light, low contrast, muted saturation"

# ── 構圖（美術風格聖經 §3.1）────────────────────────────────────────────
# 「主體基部落在 60% 高度」是正面指定，不要寫成「下方留白」——龐貝第 4 輪實測
# 那個措辭會讓空白地面吃掉 45–50% 畫面。
COMPO="Vertical 9:16 portrait composition for a mobile screen. THE BASE OF THE MAIN SUBJECT SHOULD SIT AT ABOUT 60% OF IMAGE HEIGHT. Horizon line at 40-50% of image height. The identifying feature of the place must be in the upper half of the frame. The lower 35% is a texture band — wet cobbles, puddles, mud, trampled straw — low information but never empty. No people: characters are drawn on a separate layer. Three depth layers with aerial perspective."

# ── 考據正面描述（第一道防線，§5.0）────────────────────────────────────
KEEP="Historically grounded France, October 1789, on the eve of the Revolution. Architecture is French Baroque and Neoclassical of the Ancien Regime: pale ashlar limestone, steep blue-grey slate mansard roofs, tall rectangular multi-pane casement windows with small glazing bars, wrought-iron balconies, gilded lead ornament used sparingly. NOT Gothic, NOT Renaissance Italian, NOT Victorian, NOT 19th-century Haussmann boulevards. Streets are narrow, unpaved or roughly cobbled, with an open central gutter — NOT wide modern avenues, NOT sidewalks. No gas lamps, no chimneys of industrial type. SHOPFRONTS ARE SMALL OPENINGS: a plain timber door, removable wooden boards or a hinged shutter-counter, and a sign hanging out over the street on an iron bracket. The joinery is bare or limewashed and weathered, never a smooth coat of bright paint. Do NOT draw a continuous glazed display window, and do NOT draw a fitted painted shopfront facade — those belong to the 19th century."

# 為什麼 KEEP 裡要正面寫店面：第一輪出圖的 bg_paris_bakery 右側跑出漆面乾淨的
# 紅色木框大玻璃分格店鋪，是十九世紀布爾喬亞店面。它技術上不是 plate glass，
# 所以下面那條負面提示擋不住——證明風格聖經 §5.0 是對的：考據靠正面描述，
# 負面提示只是第二道網。見 前置查證.md §2.3。
NEG="anime, cel shading, glossy, neon, oversaturated, gothic arches, pointed arches, medieval, Renaissance, Victorian, Haussmann facades, gas street lamps, plate glass shopfronts, glazed display windows, painted shopfront joinery, industrial chimneys, modern clothing, eyeglasses, wristwatch, plastic, tomatoes, corn, potatoes, chili peppers, text watermark, signature, lettering"

# ⚠️ 室內場景要覆寫 COMPO 的質感帶。
# COMPO 那句「下方 35% 是濕石板、泥、稻草」預設了室外——實測鏡廳、王后寢宮
# 這幾張會在室內地板前面長出一條戶外泥地。**實務上它被對話框蓋掉，不致命**，
# 但下次畫室內背景時用這個覆寫：
INTERIOR_COMPO=" The lower 35% is a texture band of INTERIOR floor — parquet, marble, worn boards, a rug edge — low information but never empty. NO mud, NO cobbles, NO straw, NO outdoor ground."

# 部分場景需要覆寫 KEEP 的某一條、或補強構圖（見各 key 的註解）。預設為空。
KEEP_OVERRIDE=""
COMPO_EXTRA=""

case "$1" in
# ── 1. 宮殿：識別特徵測試 ──────────────────────────────────────────────
# 驗「AI 認不認得 1789 的凡爾賽」而不是通用宮殿。大理石中庭是最強識別特徵：
# 黑白菱形鋪面 + 磚紅與石材相間的立面 + 鍍金欄杆，那是路易十三舊城堡的核心。
cour) F="bg_cour_de_marbre"; S="THE SUBJECT OF THIS PICTURE IS THE MARBLE COURTYARD (Cour de Marbre) AT THE HEART OF THE PALACE OF VERSAILLES, seen from ground level looking in. Its identifying features, all in the upper half of the frame: a black-and-white diamond-patterned marble pavement; a facade of alternating red brick and pale stone with tall arched windows; a gilded wrought-iron balcony running across the first floor; steep slate roofs with gilded lead cresting above. Cold October rain is falling; the marble diamonds are slicked with water and reflect the grey sky. The courtyard is empty and waiting.";;

# ── 2. 小村莊：這個景點包的核心對比 ───────────────────────────────────
# 每日故事挖到的引擎——王后的假農村。視覺上極不尋常（宮苑裡的茅草屋），
# 也是 AI 最可能畫錯的一張：容易畫成英國鄉村或迪士尼。
hameau) F="bg_hameau"; S="THE SUBJECT OF THIS PICTURE IS THE QUEEN'S HAMLET (Hameau de la Reine) IN THE GARDENS OF VERSAILLES — a deliberately rustic model farm village built for the queen inside the royal park. Its identifying features, all in the upper half of the frame: two or three small cottages with thatched and tiled roofs and half-timbered upper storeys, their plaster DELIBERATELY PAINTED to imitate cracks and age; a round stone tower with an external spiral stair beside a still lake; a working vegetable garden and a low wooden fence. This is a real working farm, not a ruin and not a theme park — a milking pail and a wheelbarrow stand by the door. Overcast October light, the lake flat and grey with rain.";;

# ── 3. 巴黎街市：飢餓那一側 ───────────────────────────────────────────
# 對照組。同一個景點包要同時畫得出宮苑與街市，否則八篇會全在同一個房間。
bakery) F="bg_paris_bakery"; S="THE SUBJECT OF THIS PICTURE IS A NARROW PARIS STREET OUTSIDE A BAKER'S SHOP IN OCTOBER 1789. Its identifying features, all in the upper half of the frame: a low arched doorway under a projecting wooden sign board, its painted device worn; tall narrow houses of pale plaster over timber, five storeys, each floor slightly overhanging the one below, with steep slate roofs and dormer windows; shutters closed on the upper floors. The shop's wooden counter shelf is EMPTY — no bread. Cold rain, the central gutter running with water, straw trodden into mud at the threshold.";;

# ══ 第一篇〈二十公里〉所需的四張（見 第一篇_場景清單.md §4）═══════════
# 順序即劇情順序：市場 → 市政廳 → 大道 → 鐵柵門。

# ── 4. 中央市場：S01，主角的攤子 ──────────────────────────────────────
# 拂曉。全篇的起點，也是「她本來要過的那一天」。
market) F="bg_paris_market"; S="THE SUBJECT OF THIS PICTURE IS THE CENTRAL FOOD MARKET OF PARIS AT DAYBREAK, OCTOBER 1789. Its identifying features, all in the upper half of the frame: rows of open market stalls under canvas awnings stretched on wooden poles, some sagging with rainwater; behind them a long open-sided market shed on stone piers; stacked wicker baskets and empty wooden crates; a fishmonger's stall with a worn stone slab, wet and bare. Oil lanterns hang from cords strung across the space, still lit in the blue half-light before sunrise. The stalls are set out for the day but almost nothing is on them. Wet cobbles, fish scales, scattered straw.";;

# ── 5. 市政廳前廣場：S02，隊伍變成有武器的隊伍 ────────────────────────
# ⚠️ KEEP 覆寫：巴黎市政廳（1871 年焚毀前）是**法國文藝復興**風格的建築，
# 而預設 KEEP 寫了 "NOT Renaissance Italian"——那條會把正確的立面擋掉。
# 這裡改成正面指定法國文藝復興市政建築，並保留其餘各條。
# 這正是 前置查證 §2.3 學到的教訓：擋錯東西的負面詞要拿掉，不是再加一條。
hoteldeville) F="bg_hotel_de_ville"
  KEEP_OVERRIDE="Historically grounded Paris, October 1789. THE CIVIC BUILDING IS A 16TH-CENTURY FRENCH RENAISSANCE TOWN HALL: a COMPACT, SELF-CONTAINED block, only about seven bays wide, built around one tall central pavilion with an arched doorway, a clock and a small belfry above it. Its stonework is weathered and darkened by two centuries of soot and rain. Mullioned windows in regular bays, steep blue-grey slate roofs with dormers, a few sculpted niches. Ordinary tall city houses of the same period stand immediately against it on both sides, crowding it. Streets are roughly cobbled with an open central gutter, no sidewalks, no gas lamps — street lighting is oil lanterns hung from cords. No Haussmann boulevards, no Victorian or industrial elements."
  # ⚠️ 第 1 輪跑出**十九世紀重建版**的市政廳：長側翼＋大規模雕像群。
  # 那些側翼是 1837–1848 年加的，雕像計畫更晚——1789 年只有文藝復興核心，
  # 且兩側緊挨著一般街屋。上面的 "COMPACT / only about seven bays / crowded
  # by ordinary houses" 三句就是在擋這個。見 凡爾賽史實紅線 §2。
  # 第 1 輪同時構圖漂掉（地面吃 50%），故 COMPO 另行加強。
  COMPO_EXTRA=" IMPORTANT: the building must fill the upper half of the frame and its base must sit at 60% of image height. The ground occupies only the lower 35% and no more."
  S="THE SUBJECT OF THIS PICTURE IS THE COMPACT RENAISSANCE TOWN HALL OF PARIS SEEN CLOSE-TO ACROSS ITS SQUARE, MORNING, OCTOBER 1789. Its identifying features, filling the upper half of the frame: the central pavilion with its arched doorway, clock and belfry, rising directly ahead and close enough to read its carved detail; the crowding roofs of ordinary houses pressing in on either side. In front of it a wet paved square, and along one edge a low stone river parapet. Rain has begun. The square is emptied and waiting, with dropped baskets, a broken pike shaft and trampled paper left on the wet stones.";;

# ── 6. 凡爾賽大道：S03–S06，全篇三分之二的場景 ───────────────────────
# 一張吃四場。宮殿刻意畫得極小極遠——S03/S04 讀作「還很遠」，
# S06 才由旁白指出來。二十公里的體感就是這個：它一直在那裡，一直沒有變近。
road) F="bg_versailles_road"; S="THE SUBJECT OF THIS PICTURE IS THE LONG STRAIGHT ROAD FROM PARIS TO VERSAILLES IN THE RAIN, OCTOBER 1789. Its identifying features: a dead-straight unpaved avenue receding to a single vanishing point, its surface churned to deep mud and standing water; tall bare elms planted in regular rows down both sides, their last leaves stripped by rain; flat wet fields and a low grey horizon beyond. AT THE VERY END OF THE ROAD, SMALL AND DISTANT IN THE HAZE, the long roofline of an immense palace is just visible — tiny, pale, and no nearer than it was an hour ago. Cold October rain falling steadily. The lower third is churned mud, cart ruts filled with water, and a lost wooden shoe.";;

# ── 7. 宮前鐵柵門：S07 S08 E-A E-B，整個第三幕 ───────────────────────
# 空景。群眾另做一層（見 群像人物盤點 §2 變體表）。
gate) F="bg_palace_gate"; S="THE SUBJECT OF THIS PICTURE IS THE GREAT GILDED IRON GATE AND RAILING CLOSING THE FORECOURT OF THE PALACE OF VERSAILLES, seen from outside, looking in. Its identifying features, all in the upper half of the frame: a tall wrought-iron screen of close-set vertical bars topped with gilded spearheads, a monumental gate at its centre flanked by carved stone piers bearing sculpted trophies; beyond and above it the wide paved forecourt and the pale stone wings of the palace closing in on three sides, their steep slate roofs dark with rain. The gate is SHUT. Cold October rain; the gilding is dulled and running with water, the paving beyond is empty and streaming.";;


# ══ 其餘四張背景（4️⃣5️⃣6️⃣7️⃣8️⃣ 用）═════════════════════════════════════

# ── 8. 鏡廳：4️⃣ 穿過、5️⃣ 逃離、8️⃣ 最後一次點燈 ────────────────────────
mirrors) COMPO_EXTRA="$INTERIOR_COMPO"; F="bg_hall_of_mirrors"; S="THE SUBJECT IS THE GREAT MIRRORED GALLERY OF THE PALACE OF VERSAILLES AT NIGHT, seen down its length from one end. Its identifying features, all in the upper half of the frame: a long barrel-vaulted painted ceiling; a row of tall arched windows down the right side; facing them on the left a matching row of ARCHED MIRRORS made of many small glass panels in gilded frames, so that each candle is repeated again and again into the distance; gilded bronze wall-sconces and pilasters with gilded capitals; a polished parquet floor. Only a few candles are lit, low and warm, leaving most of the gallery in cold blue-grey darkness. The gallery is EMPTY.";;

# ── 9. 王后寢宮與衣帽間：4️⃣ 收行李、5️⃣ 逃離 ──────────────────────────
chamber) COMPO_EXTRA="$INTERIOR_COMPO"; F="bg_queens_chamber"; S="THE SUBJECT IS A ROYAL BEDCHAMBER AND ITS ADJOINING DRESSING CLOSET IN THE PALACE OF VERSAILLES, BY CANDLELIGHT, seen from the doorway of the closet looking in. Its identifying features, all in the upper half of the frame: walls hung with patterned silk in muted rose and grey; a tall bed with carved gilded posts and heavy drapes drawn back; gilded panelling and a large mirror over a marble chimneypiece; tall shuttered windows. In the foreground of the closet, open drawers, a folding travelling trunk standing open and empty, and folded linen stacked on a chair. Two candles only. Everything beyond their reach is in darkness.";;

# ── 10. 僕役通道與後樓梯：4️⃣6️⃣8️⃣，宮殿的背面 ─────────────────────────
# 刻意與前三張反差最大：同一座建築，沒有鍍金、沒有絲綢、沒有鏡子。
passage) COMPO_EXTRA="$INTERIOR_COMPO"; F="bg_servants_passage"; S="THE SUBJECT IS A NARROW SERVICE CORRIDOR AND BACK STAIR INSIDE A GREAT 18TH-CENTURY PALACE — the side the court never sees. Its identifying features: bare lime-washed plaster walls, scuffed and marked at shoulder height by decades of passing bodies; a low ceiling; plain unpainted wooden doors with iron latches; a worn stone spiral stair going up on the right; a single oil lamp in a wall bracket. Utterly without ornament: NO gilding, NO silk, NO mirrors, NO marble. A wooden crate and a covered basket left on the floor against the wall. Cold, dim, and very quiet.";;

# ── 11. 宮苑運河與林蔭道：6️⃣ 走出小村莊、7️⃣8️⃣ ───────────────────────
canal) F="bg_park_canal"; S="THE SUBJECT IS THE GREAT ORNAMENTAL CANAL AND ITS AVENUE IN THE GARDENS OF VERSAILLES ON A GREY OCTOBER MORNING. Its identifying features, all in the upper half of the frame: a long straight sheet of still water receding to a vanishing point; rows of tall clipped hornbeam and elm along both banks, their leaves turning and thinning; a broad gravel avenue running beside the water; a stone basin edge. Low mist lies on the water and blurs the far end completely. The clipped hedges are immaculate and the gravel is raked. NOT A SINGLE PERSON. Flat colourless morning light.";;

*) echo "unknown key: $1"; echo "可用: cour hameau bakery market hoteldeville road gate mirrors chamber passage canal"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write \
  "Use your image_gen tool to generate one image, aspect ratio 9:16 portrait. ${PREFIX}. ${S} ${COMPO}${COMPO_EXTRA} ${KEEP_OVERRIDE:-$KEEP} Avoid: ${NEG}. Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -3

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
