#!/bin/zsh
SELF="${0:A}"
# 表情差分：以定版基底為輸入圖做 image-to-image。用法: genexpr.sh <key> [<key> ...]
OUT="${SELF:h}/../美術測試"

KEEP="Everything else must stay identical to the input image: the same face and features, same age, same skin tone, same wrinkles, same hair and hair binding, same clothing and the same fabric folds, same pose, same hands, same framing and crop, same flat grey background, same lighting, same painted matte style. Do NOT redraw the figure from scratch. Change ONLY the facial expression."

case "$1" in
ph2) B="ch_philemon_base_v2"; F="ch_philemon_e02_warm";  S="a WARM GENUINE SMILE of welcome - the corners of the eyes crease, cheeks lift, mouth open just slightly in an easy smile. He is pleased to see you and is also, quietly, still calculating.";;
ph3) B="ch_philemon_base_v2"; F="ch_philemon_e03_troubled"; S="TROUBLED and caught out - the smile is gone, brows drawn together and slightly raised at the inner ends, eyes lowered a fraction, lips pressed. The look of a man who has just realised he cannot deliver what he promised.";;
ph4) B="ch_philemon_base_v2"; F="ch_philemon_e04_calculating"; S="CALCULATING and composed - expression flattened and inward, eyes slightly narrowed and focused past the viewer, mouth closed and level, jaw a little set. He is working out which of his own commitments he will have to break.";;
vi2) B="ch_vibia_base_v2"; F="ch_vibia_e02_fierce"; S="FIERCE and unyielding - chin lifted slightly, brows lowered and level, eyes hard and direct, mouth closed in a firm line. She is not pleading; she is pushing back.";;
vi3) B="ch_vibia_base_v2"; F="ch_vibia_e03_wry"; S="A WRY KNOWING HALF-SMILE - one corner of the mouth lifted, one eyebrow fractionally higher, eyes amused but tired. The smile of someone who has heard this before and is not impressed.";;
vi4) B="ch_vibia_base_v2"; F="ch_vibia_e04_softened"; S="SOFTENED and briefly kind - the hardness gone from the eyes, brows relaxed, a small closed-mouth smile that does not last long. She is doing something generous and does not want to discuss it.";;
ni2) B="ch_nikias_base_v2"; F="ch_nikias_e02_impassive"; S="COMPLETELY IMPASSIVE - a flat level stare directly at the viewer, brows still, eyes steady and unreadable, mouth closed and relaxed. No hostility and no sympathy whatsoever. He is simply stating a time.";;
ni3) B="ch_nikias_base_v2"; F="ch_nikias_e03_watchful"; S="WATCHFUL and faintly concerned - brows drawn very slightly together, eyes searching the viewer's face, mouth closed. He has decided not to say the thing he is thinking.";;
ni4) B="ch_nikias_base_v2"; F="ch_nikias_e04_weary"; S="WEARY - eyelids a little heavy, gaze lowered a fraction, the lines of the face slack with tiredness, mouth closed. The end of a long day at sea.";;
*) echo "unknown key: $1"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write "There is an existing image file in the current directory called ${B}.png - a painted visual-novel character sprite on a flat grey background. Use your image_gen tool with ${B}.png AS THE INPUT / REFERENCE IMAGE to produce an expression variant. Change the facial expression to: ${S} ${KEEP} Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -3

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
