#!/bin/zsh
SELF="${0:A}"
# 18 張表情差分（image-to-image，以基底為輸入）。用法: genexpr2.sh <key> ...
OUT="${SELF:h}/../美術測試"

KEEP="Everything else must stay identical to the input image: the same face and features, same age, same skin tone, same wrinkles and scars, same hair, same clothing and the same fabric folds, same pose, same hands, same framing and crop, same flat grey background, same lighting, same painted matte style. Do NOT redraw the figure from scratch. Change ONLY the facial expression. Push the expression slightly further than feels natural - this sprite is displayed small on a phone."

case "$1" in
lender_hard)     B=ch_lender_base;   F=ch_lender_hard;      S="HARD and immovable - brows lowered and level, eyes flat and unblinking, mouth a firm straight line. A man stating terms he will not move on.";;
lender_tired)    B=ch_lender_base;   F=ch_lender_tired;     S="EXHAUSTED and privately ashamed - eyelids heavy, gaze dropped a fraction, the calculation gone out of the face, mouth slack at the corners. He is also in debt and it shows.";;
priest_guarded)  B=ch_priest_base;   F=ch_priest_guarded;   S="GUARDED and withholding - eyes steady but giving nothing, chin lowered very slightly, mouth closed and still. He is deciding how much of the truth to release.";;
priest_weary)    B=ch_priest_base;   F=ch_priest_weary;     S="WEARY and honest - heavy-lidded, gaze lowered, brows relaxed into sadness, mouth softened. Thirty years of managing what people are willing to believe, showing all at once.";;
patron_cold)     B=ch_patron_base;   F=ch_patron_cold;      S="COLD and dismissive - chin lifted slightly, eyes narrowed a fraction and looking down the nose, mouth level and closed. Dismissal that costs him no effort at all.";;
thea_stern)      B=ch_thea_base;     F=ch_thea_stern;       S="STERN - brows drawn down level, eyes fixed and direct, mouth pressed firm. The look that makes a child climb down off a roof immediately.";;
thea_afraid)     B=ch_thea_base;     F=ch_thea_afraid;      S="AFRAID - eyes wide, brows raised and pulled together at the inner ends, lips slightly parted, the face gone still. She has just looked up at the sky.";;
salvia_busy)     B=ch_salvia_base;   F=ch_salvia_busy;      S="DISTRACTED and calculating - eyes directed slightly to one side and unfocused, brows faintly drawn, mouth held tight. She is adding figures in her head and only half present.";;
master_impatient)B=ch_master_base;   F=ch_master_impatient; S="IMPATIENT - chin raised, eyes turned slightly away, brows flattened, mouth closed and pulled to one side. A young man who wants the conversation to be over.";;
master_afraid)   B=ch_master_base;   F=ch_master_afraid;    S="AFRAID and trying to hide it - eyes widened and fixed, brows raised at the inner ends, jaw slightly slack, all authority gone out of the face.";;
steward_urgent)  B=ch_steward_base;  F=ch_steward_urgent;   S="URGENT - brows drawn hard, eyes sharp and focused, mouth open slightly as if mid-instruction, neck tendons showing. He is giving orders fast.";;
hylas_scared)    B=ch_hylas_base;    F=ch_hylas_scared;     S="FRIGHTENED - eyes very wide, brows raised and pulled together, shoulders drawn up slightly, mouth closed tight. A child who does not know what to do and is waiting to be told.";;
orestes_calm)    B=ch_orestes_base;  F=ch_orestes_calm;     S="COMPLETELY CALM - eyes level and unhurried, brows relaxed, a faint softening at the mouth. Not gentle - simply beyond being surprised by anything.";;
orestes_urgent)  B=ch_orestes_base;  F=ch_orestes_urgent;   S="URGENT - brows drawn hard together, jaw set, eyes fixed intently on the viewer, mouth open slightly as if giving a short instruction.";;
pliny_curious)   B=ch_pliny_base;    F=ch_pliny_curious;    S="INTENSELY CURIOUS - brows raised, eyes bright and fixed on something far away and above, mouth slightly open. A naturalist looking at a thing that has no name yet and composing its description.";;
pliny_labored)   B=ch_pliny_base;    F=ch_pliny_labored;    S="STRUGGLING TO BREATHE - mouth open, breathing visibly, brows drawn together, face flushed and damp, eyes tired but still alert. The asthma and the fouled air together.";;
officer_hard)    B=ch_officer_base;  F=ch_officer_hard;     S="HARD - brows lowered, eyes narrowed against wind and spray, mouth a flat line. Giving an order he will not repeat.";;
survivor_sharp)  B=ch_survivor_base; F=ch_survivor_sharp;   S="SHARP and suspicious - eyes narrowed, chin lifted, mouth pulled in tight. She is measuring a stranger and has not decided anything yet.";;
*) echo "unknown: $1"; exit 1;;
esac

cd "$OUT" || exit 1
codex exec --skip-git-repo-check --sandbox workspace-write "There is an existing image file in the current directory called ${B}.png - a painted visual-novel character sprite on a flat grey background. Use your image_gen tool with ${B}.png AS THE INPUT / REFERENCE IMAGE to produce an expression variant. Change the facial expression to: ${S} ${KEEP} Then copy the generated file into the current directory as ${F}.png using cp, and run ls to verify it exists. Print the filename." 2>&1 | tail -2

shift
if [ $# -gt 0 ]; then exec "$SELF" "$@"; fi
