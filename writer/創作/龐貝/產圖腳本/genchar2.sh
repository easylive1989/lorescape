#!/bin/zsh
SELF="${0:A}"
# 立繪基底 v2：強化繪畫錨定 ＋ 數值化框取與打光。用法: genchar2.sh <key> [<key> ...]
OUT="${SELF:h}/../美術測試"

# 繪畫錨定放在最前面且最用力——第 5 輪的教訓是「character portrait」會把模型拉進人像攝影慣例
STYLE="A PAINTED FIGURE STUDY FOR AN ARCHAEOLOGICAL RECONSTRUCTION ILLUSTRATION OF POMPEII. This is a PAINTING, not a photograph. Painted by the same hand that paints the architectural reconstruction views of the city: realistic digital matte painting, visible painterly handling in the fabric folds and the skin, softly painted edges, matte surface, no photographic depth of field, no lens blur, no studio vignette, no glossy highlights on the skin. Roman fresco palette of red ochre, yellow ochre, Egyptian blue, green earth, lime white, muted saturation."

FRAME="This is a VISUAL NOVEL CHARACTER SPRITE for a mobile game, PORTRAIT orientation aspect ratio 2:3. FRAMING, follow exactly: the top of the head sits about 8 percent down from the top edge; the figure is CROPPED AT THE WAIST at the bottom edge; the figure is CENTRED horizontally and fills about 70 percent of the frame width; the body is turned very slightly to one side, the head upright, the eyes looking at the viewer. LIGHTING, follow exactly: one soft key light from the UPPER LEFT at about 45 degrees, producing a visible soft shadow down the RIGHT side of the face and the RIGHT side of the neck; even flat illustration lighting elsewhere; NO rim light, NO dramatic chiaroscuro, NO warm spotlight. BACKGROUND, follow exactly: one single completely FLAT UNIFORM MEDIUM GREY FIELD filling the entire background, absolutely even, NO vignette, NO gradient, NO darkening at the corners, NO cast shadow behind the figure, NO scenery - the figure will be cut out from it. Expression: neutral and at rest, mouth closed - this is the base pose from which expression variants will be derived."

RULES="Historical accuracy for Pompeii in 79 AD: authentic Roman dress of woven wool or linen, draped and pinned or belted, NO buttons, NO zips, NO stitched modern tailoring. NO eyeglasses, NO modern hairstyle, NO modern makeup, NO gold signet ring, NO weapons. NO text, NO lettering, NO watermark, NO signature, NO border. Avoid: photograph, photorealistic portrait photography, studio headshot, anime, cel shading, plastic skin, medieval or Renaissance costume, fantasy armour, landscape orientation."

case "$1" in
philemon) F="ch_philemon_base_v2"; S="THE CHARACTER: Aulus Umbricius Philemon, a Roman FREEDMAN in his late forties, grown wealthy from a fish-sauce workshop in Pompeii. Solid and well fed, thick neck, broad shoulders. Broad olive-skinned face, close-cropped greying dark hair receding slightly, clean shaven, heavy brows, laughter lines at the eyes - a man who smiles easily and calculates constantly. Dress: a good cream wool tunica with a pair of narrow red-ochre vertical stripes running over each shoulder, and a warm ochre mantle draped over the left shoulder and forearm. Prosperous but NOT aristocratic - his wealth is new and he knows it.";;
vibia) F="ch_vibia_base_v2"; S="THE CHARACTER: Vibia, a Roman woman of about forty who runs a bakery in Pompeii alone since her husband died. Sturdy, strong forearms. Sun-weathered olive skin, straight dark brows, a direct level gaze that does not soften, lines at the mouth. Hair dark and greying at the temples, pulled back plainly and bound at the nape with a simple cloth band - NOT an elaborate elite coiffure, NO ringlets. Dress: a plain undyed wool tunica belted with a cord, a dull green-earth mantle pushed back off the shoulders so her arms are free. Flour dust on her forearms, dark under the fingernails.";;
nikias) F="ch_nikias_base_v2"; S="THE CHARACTER: Nikias, a Greek merchant-ship captain of about fifty. Lean, wiry, weather-hardened. Deeply sun-darkened creased face with pale squint lines fanning from the corners of the eyes where the sun has not reached, a short grizzled grey beard, close-cut grey hair. Expression flat, patient, unsentimental. Dress: a plain undyed working tunica belted with rope, the right shoulder left bare in the practical seafarer style, a coarse dark-red cloak fastened at the left shoulder. Rope-callused hands, a plain leather cord at the neck.";;
*) echo "unknown key: $1"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write "Use your image_gen tool to generate ONE image in PORTRAIT orientation aspect ratio 2:3 (about 1024x1536), then copy the generated file into the current directory as ${F}.png using cp, then run ls to verify it exists. Use this prompt: ${STYLE} ${FRAME} ${S} ${RULES}" 2>&1 | tail -3

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
