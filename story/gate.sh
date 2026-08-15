#!/usr/bin/env bash
# 本機與 CI 共用的出貨閘門：素材匯入 → 內容檢查 → 靜態分析 → 測試 → build web。
#
# **這支不做部署。** 最後一步由兩個入口各自接手：
#   本機  story/deploy.sh              → firebase deploy（用你的 firebase login）
#   CI    .github/workflows/deploy-story.yml → action-hosting-deploy（用 service account）
#
# 為什麼抽出來：閘門在兩個地方各寫一份，遲早分岔，然後「CI 綠燈」變成
# 「CI 沒跑到的那幾步剛好是壞的」。一份腳本，兩個入口。
#
# 用法：
#   ./gate.sh                完整：重跑素材匯入（去背＋轉檔）
#   ./gate.sh --skip-import  跳過匯入，沿用現有產物（素材沒動時省 2 分鐘）
#   ./gate.sh --ci           CI 模式：不做影像處理，只驗證版控裡的產物
#
# **--ci 為什麼不做影像處理**：去背與轉檔要在 125 張圖上跑 Pillow＋numpy，
# 而 CI 上沒有 _processed 快取（那份 568 MB，不可能進版控）。所以 WebP 產物
# 直接進版控（18 MB），CI 只回答一個問題：版控裡這批東西能不能出貨。
# 分工是刻意的——**影像處理留在有素材、有快取的本機**：
#   美術動了 → 本機重跑匯入 → 把 WebP 一起 commit → CI 部署
#   只改劇本文字 → 本機重跑匯入（很快，快取全中）→ commit → CI 部署
# 忘記重跑的話 --ci 的 --verify-only 會擋下來（產物與來源逐字比對）。
#
# 環境變數：
#   FLUTTER  預設 "fvm flutter"。CI 上設成 "flutter"——那邊 SDK 由
#            subosito/flutter-action 依 .fvmrc 的版本裝好，沒有 fvm。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
cd "$HERE"
: "${FLUTTER:=fvm flutter}"

# 景點包清單只有一份真相：import_pack.py 的 PACKS。這裡用問的，不用抄的。
packs=$(python3 -c "
import sys; sys.path.insert(0, 'tool'); import import_pack
print(' '.join(import_pack.PACKS))")

# ── 前置：每個包的來源都得在，缺一包就停 ───────────────────────────
#
# packs.json 是掃磁碟產生的，少匯入一包，線上書架就少一個景點——而部署會
# 覆蓋掉線上的舊版。所以「來源不存在」必須是硬錯誤，不能降級成跳過。
for p in $packs; do
  src="$ROOT/$(python3 -c "
import sys; sys.path.insert(0, 'tool'); import import_pack
print(import_pack.PACKS['$p']['src'])")"
  if [[ ! -d "$src" ]]; then
    echo "✗ 景點包 $p 的來源不存在：$src"
    echo "  這通常表示該包還沒進版控（fresh clone / CI 上會這樣）。"
    echo "  要嘛把它加進版控，要嘛從 story/tool/import_pack.py 的 PACKS 移除。"
    echo "  **不要**用 --partial 繞過——那會把缺篇的書架推上線。"
    exit 1
  fi
done

MODE="${1:-}"

case "$MODE" in
  --ci)
    echo "▶ 驗證版控裡的匯入產物（CI 不做影像處理）"
    for p in $packs; do
      python3 tool/import_pack.py --pack "$p" --verify-only
    done
    ;;
  --skip-import)
    echo "▶ 跳過素材匯入"
    [[ -d assets/content/pompeii-79/assets/backgrounds ]] || {
      echo "✗ 素材目錄不存在，不能跳過匯入——先跑一次不帶 --skip-import"; exit 1; }
    ;;
  *)
    for p in $packs; do
      echo "▶ 從 writer vault 匯入素材（$p）"
      # 🔒 部署路徑上**不加** --partial／--skip-verify。那兩個是製作中的旗標，
      # 一旦進了閘門，缺篇與破圖就會被靜默推上線。要出貨就得先補齊。
      python3 tool/import_pack.py --pack "$p"
    done
    ;;
esac

echo "▶ 內容守門（凡爾賽）"
# story_tool.py check 驗結構與變數；這支驗內容——反君主制、時代錯置、
# 「之後」段的評價字眼、轉檔遺失。寫壞了不會報錯，但整個包就毀了。
python3 "$ROOT/writer/創作/凡爾賽/產圖腳本/lint_content.py"

echo "▶ 劇本結構與矛盾檢查（全部景點包）"
# 結構（節點長度／資產／跳轉／可達）＋ 兩個語意 lint：變數空轉與假選項、
# 節點上的 assumes 前提。見 writer/製作規範/劇本矛盾檢查規範.md §7。
fail=0
for story in "$ROOT"/writer/創作/*/stories/*/; do
  [[ -f "$story/story.json" ]] || continue
  # 過的只印最後一行（統計＋✅），沒過的把完整輸出印出來——閘門擋下來的時候，
  # 人要的是「哪一條壞了」，不是「有東西壞了」。
  if out=$(python3 "$ROOT/writer/製作規範/story_tool.py" check "$story" 2>&1); then
    printf '  %-24s %s\n' "$(basename "$story")" "$(tail -1 <<<"$out")"
  else
    printf '  %-24s\n' "$(basename "$story")"
    sed 's/^/    /' <<<"$out"
    fail=1
  fi
done
[[ $fail -eq 0 ]] || { echo "✗ 有劇本沒過檢查"; exit 1; }

echo "▶ 取得套件"
$FLUTTER pub get

echo "▶ 靜態分析"
$FLUTTER analyze --fatal-infos

echo "▶ Flutter 測試"
$FLUTTER test

if [[ "$MODE" != "--ci" ]]; then
  echo "▶ 匯入腳本測試"
  # 這組測試會實際跑一次匯入（去背、對齊、WebP 品質都是拿真實輸出量的），
  # 所以它跟影像處理綁在一起，只在本機跑。CI 那邊由 --verify-only 接手。
  (cd "$ROOT" && python3 -m pytest story/tool/test_import_pack.py -q)
else
  echo "▶ 跳過匯入腳本測試（會實際跑匯入，只在本機跑）"
fi

echo "▶ Build web"
$FLUTTER build web --release

echo "✅ 閘門全過，story/build/web 可以部署"
