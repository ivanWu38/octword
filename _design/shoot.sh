#!/bin/bash
# Octordle/_design/shoot.sh — 一鍵建「截圖庫」：iPhone＋iPad × 所有主要畫面 → _design/shots/
# 用法：bash _design/shoot.sh            （全部）
#       bash _design/shoot.sh iphone     （只截 iPhone）
#       bash _design/shoot.sh ipad
# 改 demo 數字 → 改 Octordle/Utils/PreviewSeed.swift；換畫面/外觀 → 改下面 screens()，重跑即可。
set -euo pipefail
source ~/.claude/skills/app-store-previews/scripts/shotlib.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
export BUNDLE_ID="com.ikuhei.octordle"
export SHOTS="$HERE/shots"; mkdir -p "$SHOTS"
SCHEME="Octordle"; PROJ="$HERE/../Octordle.xcodeproj"
BUILD="$HERE/../build_shots"
SEED="OCTORDLE_PREVIEW_SEED=1 OCTORDLE_NO_ADS=1"

# 每次啟動前清掉 app 的 UserDefaults，讓 seed 每次都從乾淨狀態寫入（服務 singleton 在 init 就讀 defaults）。
wipe() { xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true; xcrun simctl spawn "$UDID" defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true; }
go() { wipe; launch "$SEED OCTORDLE_SCREEN=$1 OCTORDLE_APPEARANCE=$2" "${3:-3}"; }

screens() {
  statusbar
  for mode in light dark; do
    appearance "$mode"
    go game       "$mode" 4; shot "game_$mode"
    go today      "$mode";   shot "today_$mode"
    go rank       "$mode" 4; shot "rank_$mode"
    go report     "$mode" 5; shot "report_$mode"
    go explore    "$mode";   shot "explore_$mode"
    go challenges "$mode";   shot "challenges_$mode"
    go categories "$mode";   shot "categories_$mode"
    go unlimited  "$mode";   shot "unlimited_$mode"
    go journey    "$mode";   shot "journey_$mode"
  done
}

which="${1:-all}"
if [[ "$which" == "iphone" || "$which" == "all" ]]; then
  boot "iPhone 17 Pro Max" iphone; build_install "$SCHEME" "$PROJ" "$BUILD"; screens; shutdown_sim
fi
if [[ "$which" == "ipad" || "$which" == "all" ]]; then
  boot "iPad Air 11-inch (M3)" ipad; build_install "$SCHEME" "$PROJ" "$BUILD"; screens; shutdown_sim
fi
echo "done → $SHOTS  (manifest.json 已更新)"
