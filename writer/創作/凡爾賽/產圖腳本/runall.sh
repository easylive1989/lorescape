#!/bin/zsh
# 等目前兩批產圖跑完，接著把剩下的全部跑掉。中間不留空檔。
cd "${0:A:h}"
while pgrep -f "genchar2.sh|genbg.sh" >/dev/null; do sleep 20; done
echo "▶ 前兩批完成"

./genchar2.sh marguerite
echo "▶ 瑪格麗特基底完成"

./genexpr.sh anne_flat anne_asking jacquot_eager bertin_pressing \
             officer_tired officer_hard marguerite_worn \
             suzanne_guarded gervais_stopped etienne_asking \
             sergeant_grim sergeant_relief gardener_dry \
             womana_certain womana_laughing clerk_flat
echo "▶ 16 個表情差分完成"

./gencg2.sh shelf staying trunk balcony milk knots lastlight
echo "▶ 7 張全螢幕 CG 完成"
echo "✅ 全部產圖結束"
