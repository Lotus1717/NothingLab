#!/usr/bin/env bash
# Flutter 国内镜像环境变量 — source 此文件后使用 flutter 命令
# 用法: source scripts/flutter_env.sh [cfug|sjtu|tuna]

MIRROR="${1:-cfug}"

case "$MIRROR" in
  cfug)
    export PUB_HOSTED_URL=https://pub.flutter-io.cn
    export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
    ;;
  sjtu)
    export PUB_HOSTED_URL=https://mirror.sjtu.edu.cn/dart-pub
    export FLUTTER_STORAGE_BASE_URL=https://mirror.sjtu.edu.cn
    ;;
  tuna)
    export PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
    export FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
    ;;
  *)
    echo "未知镜像: $MIRROR (可选: cfug, sjtu, tuna)" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

if [ -d "$HOME/flutter/bin" ]; then
  export PATH="$HOME/flutter/bin:$PATH"
elif [ -d "$HOME/development/flutter/bin" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

echo "✓ 镜像: $MIRROR"
echo "  PUB_HOSTED_URL=$PUB_HOSTED_URL"
echo "  FLUTTER_STORAGE_BASE_URL=$FLUTTER_STORAGE_BASE_URL"
echo "  Flutter: $(command -v flutter 2>/dev/null || echo '未找到')"
