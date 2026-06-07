#!/usr/bin/env bash
# 拉取千问 MLX 模型（可选，默认不打包进 App）
#
# 模型 bundling 已改为 opt-in，Release/Debug 构建不会自动下载或嵌入 ~200MB 模型。
# 需要本地测试 MLX 千问时手动执行：
#   BUNDLE_MODEL=1 bash scripts/fetch_bundled_model.sh
# 并在 Xcode 中临时将 Models 目录加回 Copy Bundle Resources（见 README）。
#
# 环境变量：
#   BUNDLE_MODEL=1       执行下载（默认跳过）
#   SKIP_BUNDLE_MODEL=1  显式跳过（与默认行为相同）
set -euo pipefail

if [[ "${SKIP_BUNDLE_MODEL:-}" == "1" || "${BUNDLE_MODEL:-}" != "1" ]]; then
  echo "Skipping bundled model fetch (opt-in: BUNDLE_MODEL=1 bash $0)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_DIR="$ROOT/ios/Runner/Models/Qwen2.5-0.5B-Instruct-4bit"
BASE="${HF_ENDPOINT:-https://hf-mirror.com}/mlx-community/Qwen2.5-0.5B-Instruct-4bit/resolve/main"
MIN_MODEL_BYTES=$((200 * 1024 * 1024))

FILES=(
  added_tokens.json
  config.json
  merges.txt
  model.safetensors
  model.safetensors.index.json
  special_tokens_map.json
  tokenizer.json
  tokenizer_config.json
  vocab.json
)

file_size() {
  if stat -f%z "$1" >/dev/null 2>&1; then
    stat -f%z "$1"
  else
    stat -c%s "$1"
  fi
}

needs_download() {
  local dest="$1"
  local name="$2"
  [[ ! -f "$dest" ]] && return 0
  if [[ "$name" == "model.safetensors" ]]; then
    local size
    size="$(file_size "$dest")"
    [[ "$size" -lt "$MIN_MODEL_BYTES" ]]
    return
  fi
  return 1
}

mkdir -p "$MODEL_DIR"

# 清理已弃用的 base 模型，避免误打进安装包
LEGACY_DIR="$ROOT/ios/Runner/Models/Qwen2.5-0.5B-4bit"
if [[ -d "$LEGACY_DIR" ]]; then
  rm -rf "$LEGACY_DIR"
  echo "Removed legacy base model at $LEGACY_DIR"
fi

for f in "${FILES[@]}"; do
  dest="$MODEL_DIR/$f"
  if needs_download "$dest" "$f"; then
    if [[ -f "$dest" ]]; then
      echo "⚠ $f incomplete, re-downloading"
      rm -f "$dest"
    else
      echo "↓ $f"
    fi
    if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 3600 -L "$BASE/$f" -o "$dest"; then
      rm -f "$dest"
      echo "error: failed to download $f from $BASE" >&2
      echo "hint: large file may need VPN; set HF_ENDPOINT if using another mirror" >&2
      exit 1
    fi
  else
    echo "✓ $f already exists"
  fi
done

echo "Done: $(du -sh "$MODEL_DIR" | awk '{print $1}') at $MODEL_DIR"
