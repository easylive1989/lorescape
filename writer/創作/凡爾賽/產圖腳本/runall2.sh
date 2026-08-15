#!/bin/zsh
# 序列跑完剩餘產圖。**一次只跑一條鏈**——平行跑會讓 codex 卡死（實測 22:07
# 那次兩條鏈同時開，背景那條卡了 25 分鐘沒有任何產出）。
cd "${0:A:h}"
set -x
./genbg.sh mirrors chamber passage canal
./genchar2.sh marguerite
./genexpr.sh anne_flat anne_asking jacquot_eager bertin_pressing \
             officer_tired officer_hard marguerite_worn \
             suzanne_guarded gervais_stopped etienne_asking \
             sergeant_grim sergeant_relief gardener_dry \
             womana_certain womana_laughing clerk_flat
./gencg2.sh shelf staying trunk balcony milk knots lastlight
echo "✅ 全部產圖結束"
