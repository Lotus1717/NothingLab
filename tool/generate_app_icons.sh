#!/usr/bin/env bash
# 从 assets/icon/app_icon_1024.png 重新导出 Web 图标，并刷新各平台启动图标。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/flutter/bin:${PATH:-}"

cd "$ROOT"
bash "$ROOT/tool/resize_web_icons.sh"
dart run flutter_launcher_icons
echo "All launcher icons regenerated."
