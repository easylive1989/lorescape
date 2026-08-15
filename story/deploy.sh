#!/bin/zsh
# 從本機部署到 https://story-lorescape.web.app
#
# 閘門在 gate.sh（本機與 CI 共用），這支只多做最後一步：用你本機的
# firebase login 部署。CI 的入口是 .github/workflows/deploy-story.yml，
# 跑同一支 gate.sh，換成 service account 部署。
#
# 手動玩過 8 篇 ×3 結局要兩小時，不會有人每次改動都重玩——擋在閘門裡的
# 那 173 條測試與劇本 lint 才是真正天天在守的東西。
#
# 用法：
#   ./deploy.sh              完整：匯入素材 → 閘門 → build → 部署
#   ./deploy.sh --skip-import 跳過素材匯入（素材沒動時省 2 分鐘）
set -e

cd "${0:A:h}"
ROOT="${0:A:h:h}"

./gate.sh "$@"

echo "▶ 部署"
(cd "$ROOT" && firebase deploy --only hosting:story)

echo "✅ https://story-lorescape.web.app"
