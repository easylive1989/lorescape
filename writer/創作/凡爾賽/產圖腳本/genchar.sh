#!/bin/zsh
SELF="${0:A}"
# 〈二十公里〉的 3 個立繪基底（2:3 直幅）。用法: genchar.sh <key> [<key> ...]
#
# STYLE 換掉了龐貝的壁畫色票（那是龐貝的考據結論），改用凡爾賽的十月雨色票，
# 與 genbg.sh 一致。FRAME 一字未改——那是立繪的通用規格，跟景點無關，
# 產線的一致性就靠它。RULES 來自 服裝規格表 §4.3。
OUT="${SELF:h}/../美術測試"

STYLE="A PAINTED FIGURE STUDY FOR A HISTORICAL RECONSTRUCTION ILLUSTRATION OF PARIS AND VERSAILLES IN OCTOBER 1789. This is a PAINTING, not a photograph. Painted by the same hand that paints the architectural reconstruction views: realistic digital matte painting, visible painterly handling in the fabric folds and the skin, softly painted edges, matte surface, no photographic depth of field, no lens blur, no studio vignette, no glossy highlights on the skin. Late-18th-century French palette — wet pale limestone, slate blue-grey, rain-desaturated green, mud brown, undyed and indigo and russet wool, with dull crimson as the only warm accent. Low contrast, muted saturation, overcast light."

FRAME="This is a VISUAL NOVEL CHARACTER SPRITE for a mobile game, PORTRAIT orientation aspect ratio 2:3. FRAMING, follow exactly: the top of the head sits about 8 percent down from the top edge; the figure is CROPPED AT THE WAIST at the bottom edge; the figure is CENTRED horizontally and fills about 70 percent of the frame width; the body is turned very slightly to one side, the head upright, the eyes looking at the viewer. LIGHTING, follow exactly: one soft key light from the UPPER LEFT at about 45 degrees, producing a visible soft shadow down the RIGHT side of the face and the RIGHT side of the neck; even flat illustration lighting elsewhere; NO rim light, NO dramatic chiaroscuro. BACKGROUND, follow exactly: one single completely FLAT UNIFORM MEDIUM GREY FIELD filling the entire background, absolutely even, NO vignette, NO gradient, NO darkening at the corners, NO cast shadow behind the figure, NO scenery. Expression: neutral and at rest, mouth closed - this is the base pose from which expression variants will be derived."

# 服裝規格表 §4.3 的正面描述。**不是靠負面提示**——前置查證 §2.3 的店面錯置
# 已經實證負面提示擋不住年代錯置。
RULES="Historical accuracy for France in OCTOBER 1789, before the Revolution had names for its sides. WOMEN wear layered dress: a linen shift, a stiffened supporting bodice giving a firm shaped waist (working women wore these too - NOT a loose unsupported peasant smock), a fitted short jacket or plain gown, a coarse apron tied at the waist, a folded linen kerchief covering the chest and tucked into the front, and a linen cap covering most of the hair. MEN wear knee breeches with stockings, a linen shirt, a long waistcoat and a coat - NEVER long trousers. Wool and linen, undyed or indigo or russet or brown; no silk, no lace, no embroidery on common people. EVERYONE has something on their head. NO red Phrygian cap, NO tricolour sash, NO Napoleonic uniform, NO guillotine - all of those are years later. NO eyeglasses, NO modern hairstyle, NO modern makeup. NO text, NO lettering, NO watermark, NO signature, NO border. Avoid: photograph, photorealistic portrait photography, studio headshot, anime, cel shading, plastic skin, medieval or Renaissance costume, Victorian dress, fantasy costume, landscape orientation."

case "$1" in
# 卡特琳｜服裝規格表 §2 A（巴黎勞動女性）。她是把主角捲進去的人。
catherine) F="ch_catherine_base"; S="THE CHARACTER: Catherine Aubry, a Paris market woman of about forty-five who sells eggs and cheese two stalls down from the protagonist. Build: broad through the shoulders, solid, a woman who lifts crates every morning. Face: weathered pale skin reddened across the cheekbones by weather, greying brown hair almost entirely hidden under a plain linen cap, deep lines at the mouth, steady unhurried eyes that have already decided something and are waiting for you to catch up. Dress: a fitted short jacket of coarse indigo-dyed wool over a linen shift, a firm shaped waist, a heavy brown wool petticoat, a coarse undyed apron, and a folded linen kerchief crossed over her chest. A grey wool shawl over her shoulders, damp. Everything worn soft with washing. A small tricolour cockade is pinned to her cap.";;

# 佩琳｜同 A 組，但年輕、更窮、衣服更舊。她中途退出。
perrine) F="ch_perrine_base"; S="THE CHARACTER: Perrine, a young Paris woman of nineteen who joined the crowd because the people in front of her started walking. Build: slight, thin, narrow shouldered, not strong. Face: very pale skin with no colour in it at all, fine light brown hair escaping from under a limp linen cap, large uncertain eyes, mouth slightly open as if about to ask a question she has not formed. She looks cold. Dress: a fitted short jacket of faded brown wool, patched at one elbow, over a linen shift with a shaped supporting waist; a thin grey petticoat; a coarse apron; a linen kerchief pulled tight at the throat against the cold. Her clothes are older and thinner than the other women's. No shawl.";;

# 馬亞爾｜真實人物。服裝規格表 §2 J（資產階級）。
# ⚠️ 比照龐貝對老普林尼的處理：明說「這是依時代服飾的想像形象」，
# 不宣稱是肖像。他的角色包含**節制群眾**，不可畫成煽動者（凡爾賽史實紅線 §1.4）。
maillard) F="ch_maillard_base"; S="THE CHARACTER: Stanislas Maillard, about二十七, a court usher from Paris who took a leading part in organising the march - NOTE: this is an imagined likeness in period-correct dress, not a portrait. He is NOT a firebrand and must not look like one: his documented role included RESTRAINING the crowd. Build: not tall, wiry, upright, holds himself carefully. Face: thin, pale, sharp featured, dark hair tied back plainly at the nape without powder, clean shaven, quick intelligent eyes that are watching the crowd rather than addressing it, mouth closed and controlled. Dress: knee breeches and stockings, a linen shirt with a plain white neckcloth, a long waistcoat and a dark blue-grey wool coat - better made than the women's clothes but not by very much, and soaked through. A tricolour cockade on the hat he holds against his chest.";;

*) echo "unknown: $1"; echo "可用: catherine perrine maillard"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write \
  "Use your image_gen tool to generate ONE image in PORTRAIT orientation aspect ratio 2:3 (about 1024x1536), then copy the generated file into the current directory as ${F}.png using cp, then run ls to verify it exists. Use this prompt: ${STYLE} ${FRAME} ${S} ${RULES}" 2>&1 | tail -2

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
