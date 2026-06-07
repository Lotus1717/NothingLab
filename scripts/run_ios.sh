#!/usr/bin/env bash
# 真机运行（自动加载国内镜像 + Flutter PATH）
# 用法:
#   bash scripts/run_ios.sh
#   bash scripts/run_ios.sh --profile -d 00008150-001605D61A47401C

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f "$HOME/.config/flutter/env.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.config/flutter/env.sh"
elif [ -f "$ROOT/scripts/flutter_env.sh" ]; then
  # shellcheck source=/dev/null
  source "$ROOT/scripts/flutter_env.sh" "${FLUTTER_MIRROR:-cfug}"
fi

exec flutter run "$@"
