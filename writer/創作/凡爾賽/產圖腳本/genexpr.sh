#!/bin/zsh
SELF="${0:A}"
# 〈二十公里〉的 6 張表情差分（image-to-image，以基底為輸入）。
# 用法: genexpr.sh <key> [<key> ...]
#
# KEEP 一字不改地沿用龐貝版——它是差分產線的核心契約，改了就會跑掉五官與
# 服裝，而 import_pack.py 的對齊（align_to_base）是靠「除了表情什麼都一樣」
# 這個前提才對得準的。
OUT="${SELF:h}/../美術測試"

KEEP="Everything else must stay identical to the input image: the same face and features, same age, same skin tone, same wrinkles and scars, same hair, same clothing and the same fabric folds, same pose, same hands, same framing and crop, same flat grey background, same lighting, same painted matte style. Do NOT redraw the figure from scratch. Change ONLY the facial expression. Push the expression slightly further than feels natural - this sprite is displayed small on a phone."

case "$1" in
# 卡特琳 ×3
catherine_firm)     B=ch_catherine_base; F=ch_catherine_firm;     S="DECIDED and immovable - brows level and lowered, eyes fixed steadily on the viewer, mouth closed in a firm line, chin very slightly forward. A woman who has already made up her mind and is waiting for you to catch up. Not angry.";;
catherine_weary)    B=ch_catherine_base; F=ch_catherine_weary;    S="WORN THROUGH - eyelids heavy, gaze a fraction lowered, the lines from nose to mouth deepened, mouth slack at the corners, shoulders read as dropped. She has walked all day and is asking a question she already knows the answer to.";;
catherine_softened) B=ch_catherine_base; F=ch_catherine_softened; S="SOFTENED - brows relaxed and lifted very slightly at the inner ends, eyes warmer and directly on the viewer, the firm line of the mouth eased. The look of someone who has stopped arguing and is just checking on you.";;

# 佩琳 ×2
perrine_pale)       B=ch_perrine_base;   F=ch_perrine_pale;       S="DAWNING DREAD - eyes widened a little and fixed, brows raised and drawn together at the inner ends, lips parted very slightly, all colour gone. She has just been told how far it is and is doing the arithmetic.";;
perrine_breaking)   B=ch_perrine_base;   F=ch_perrine_breaking;   S="COMING APART, but NOT crying - eyes wet and reddened at the rims, brows pulled together hard, jaw tight, mouth pressed shut and trembling at one corner. She is holding it in while she says something plain and true.";;

# 馬亞爾 ×1
maillard_raised)    B=ch_maillard_base;  F=ch_maillard_raised;    S="ADDRESSING A CROWD, with authority but NOT inflaming it - chin raised, brows lifted and level, eyes wide and directed slightly above the viewer to reach the people at the back, mouth open mid-sentence. He is calming several thousand people, not stirring them. No anger, no triumph.";;


# ══ 其餘七篇的表情差分 ═════════════════════════════════════════════════
# 每個配角 1–2 個差分。次要角色不給差分——立繪庫的成本要花在會反覆出現的臉上。

# 1️⃣ 擋板
anne_flat)       B=ch_anne_base;     F=ch_anne_flat;       S="LEVEL AND UNMOVED - brows flat, eyes steady and direct, mouth closed in a straight line. The face of someone who has said 'there is none' thirty times already today and will say it thirty more.";;
anne_asking)     B=ch_anne_base;     F=ch_anne_asking;     S="ASKING SOMETHING SHE ALREADY KNOWS THE ANSWER TO - head very slightly tilted, brows raised a fraction at the inner ends, eyes searching his face, mouth softened and about to open. Not accusing. Genuinely asking.";;
jacquot_eager)   B=ch_jacquot_base;  F=ch_jacquot_eager;   S="EAGER AND A LITTLE ANXIOUS - eyes wide and bright and fixed on the viewer, brows lifted, mouth slightly open as if he has just finished asking permission for something. A boy who wants to be told yes.";;
bertin_pressing) B=ch_bertin_base;   F=ch_bertin_pressing; S="PRESSING A CLAIM POLITELY - chin very slightly lifted, eyes steady and expectant, mouth closed in a small controlled smile that is not really a smile. Twenty years of custom, being cashed in.";;

# 3️⃣ 柵欄的兩邊
officer_tired)   B=ch_officer_base;  F=ch_officer_tired;   S="EXHAUSTED AND HONEST - eyelids heavy, gaze slightly lowered, brows relaxed out of their military set, mouth loose at the corners. The moment an officer admits he does not know what the orders mean either.";;
officer_hard)    B=ch_officer_base;  F=ch_officer_hard;    S="HARD AND CLOSED - brows lowered and level, eyes flat, jaw set, mouth a firm line. Giving an instruction he will not discuss.";;
marguerite_worn) B=ch_marguerite_base; F=ch_marguerite_worn; S="WORN THROUGH BUT NOT BROKEN - eyelids heavy, face slack with fatigue, hair wet against the temples, eyes still level and looking straight at the viewer. She has walked twenty kilometres and she is still here.";;

# 4️⃣ 三天份的行李
suzanne_guarded) B=ch_suzanne_base;  F=ch_suzanne_guarded; S="GUARDED - eyes steady but giving nothing at all, chin lowered a fraction, mouth closed and still. She is deciding how much of what she knows is safe to hand over.";;
gervais_stopped) B=ch_gervais_base;  F=ch_gervais_stopped; S="CAUGHT MID-MOTION - the composure broken for half a second: eyes unfocused and directed slightly past the viewer, brows minutely drawn, mouth open the barest amount. She has just been asked a question she cannot answer.";;
etienne_asking)  B=ch_etienne_base;  F=ch_etienne_asking;  S="ASKING, VERY QUIETLY - brows raised gently at the inner ends, eyes turned up to the viewer, mouth just parted. An old servant asking something he has no standing to ask.";;

# 5️⃣ 陽台
sergeant_grim)   B=ch_sergeant_base; F=ch_sergeant_grim;   S="GRIM AND WITHOUT ANSWERS - brows drawn hard together, eyes fixed and dark, jaw clenched, mouth shut tight. He has been given an order with a hole in it and he is about to pass it on anyway.";;
sergeant_relief) B=ch_sergeant_base; F=ch_sergeant_relief; S="RELIEF HE IS TRYING TO HIDE - the tension going out of the brows all at once, eyes closing a fraction, breath released, mouth softening. He has just been told nobody fired.";;

# 6️⃣ 牛奶
gardener_dry)    B=ch_gardener_base; F=ch_gardener_dry;    S="DRILY AMUSED, WITHOUT WARMTH - one brow fractionally higher, eyes narrowed, one corner of the mouth pulled in. He has just been asked what to do about the milk and he finds the question funny in a way that is not kind.";;

# 7️⃣ 麵包師傅一家
womana_certain)  B=ch_womana_base;   F=ch_womana_certain;  S="COMPLETELY CERTAIN - brows raised, eyes wide and bright, mouth open mid-sentence, chin forward. She is explaining what is going to happen next and she has no idea.";;
womana_laughing) B=ch_womana_base;   F=ch_womana_laughing; S="LAUGHING, HEAD BACK A LITTLE - eyes creased shut at the corners, mouth wide open in a real laugh, whole face lifted. She has just been asked something by a child and it is the funniest thing she has heard all day.";;

# 8️⃣ 今晚不點了
clerk_flat)      B=ch_clerk_base;    F=ch_clerk_flat;      S="ALREADY LOOKING BACK AT HIS PAPER - eyes directed downward and away from the viewer, brows neutral, mouth closed. Complete incuriosity. He has finished with you before you finished answering.";;

*) echo "unknown: $1"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write \
  "There is an existing image file in the current directory called ${B}.png - a painted visual-novel character sprite on a flat grey background. Use your image_gen tool with ${B}.png AS THE INPUT / REFERENCE IMAGE to produce an expression variant. Change the facial expression to: ${S} ${KEEP} Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -2

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
