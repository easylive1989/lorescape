#!/bin/zsh
# 部署到 https://story-lorescape.web.app
#
# 為什麼是本機腳本而不是 GitHub Actions：素材（60 張 WebP）不進版控，CI 上
# fresh clone 沒有 writer vault 就跑不了 import_pack.py，pubspec 宣告的 asset
# 目錄不存在會直接 build 失敗。要讓 CI 跑起來得加 LFS 或造假素材，那是為了
# CI 而生的複雜度。素材在誰的機器上，部署就在誰的機器上。
#
# 這支腳本的重點是**閘門**：analyze／測試沒過就不部署。手動玩過 8 篇 ×3 結局
# 要兩小時，不會有人每次改動都重玩——擋在這裡的那 173 條測試才是真正天天在
# 守的東西。
#
# 用法：
#   ./deploy.sh              完整：匯入素材 → 檢查 → build → 部署
#   ./deploy.sh --skip-import 跳過素材匯入（素材沒動時省 2 分鐘）
set -e

cd "${0:A:h}"
ROOT="${0:A:h:h}"

if [[ "$1" != "--skip-import" ]]; then
  echo "▶ 從 writer vault 匯入素材"
  python3 tool/import_pack.py
else
  echo "▶ 跳過素材匯入"
  [[ -d assets/content/pompeii-79/assets/backgrounds ]] || {
    echo "✗ 素材目錄不存在，不能跳過匯入——先跑一次不帶 --skip-import"; exit 1; }
fi

echo "▶ 靜態分析"
fvm flutter analyze --fatal-infos

echo "▶ Flutter 測試"
fvm flutter test

echo "▶ 匯入腳本測試"
(cd "$ROOT" && python3 -m pytest story/tool/test_import_pack.py -q)

echo "▶ Build web"
fvm flutter build web --release

echo "▶ 部署"
(cd "$ROOT" && firebase deploy --only hosting:story)

echo "✅ https://story-lorescape.web.app"
