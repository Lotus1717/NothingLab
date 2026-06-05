#!/usr/bin/env bash
# iPhone 真机调试一键准备（需已安装 Xcode）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 国内镜像（可选: cfug | sjtu | tuna）
if [ -f "$ROOT/scripts/flutter_env.sh" ]; then
  # shellcheck source=/dev/null
  source "$ROOT/scripts/flutter_env.sh" "${1:-cfug}"
fi

if [ -d "$HOME/flutter/bin" ]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi

if [ ! -d "/Applications/Xcode.app" ]; then
  echo "❌ 未检测到 Xcode.app"
  echo "请先从 App Store 安装 Xcode，然后执行："
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -runFirstLaunch"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌ xcodebuild 不可用，请先切换开发者目录："
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "📦 安装 CocoaPods..."
  gem install cocoapods --user-install
  export PATH="$HOME/.gem/ruby/$(ruby -e 'print RUBY_VERSION')/bin:$PATH"
fi

echo "📦 Flutter 依赖..."
flutter pub get

echo "🍎 安装 iOS Pods..."
cd ios
pod install
cd "$ROOT"

echo ""
echo "✅ 环境就绪。接下来："
echo "  1. 用数据线连接 iPhone，手机上点「信任此电脑」"
echo "  2. iOS 16+ 请在 设置 → 隐私与安全性 → 开发者模式 中开启"
echo "  3. 打开 Xcode 配置签名："
echo "     open ios/Runner.xcworkspace"
echo "     Runner → Signing & Capabilities → Team 选你的 Apple ID"
echo "  4. 回到终端运行："
echo "     flutter devices"
echo "     flutter run -d <你的iPhone设备ID>"
echo ""
echo "（可选）MLX 本地 AI：在 Xcode 中添加 https://github.com/ml-explore/mlx-swift"
