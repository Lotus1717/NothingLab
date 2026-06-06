#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON="$ROOT/assets/icon"
WEB="$ROOT/web"

sips -z 512 512 "$ICON/app_icon_1024.jpg" --out "$WEB/icons/Icon-512.png" >/dev/null
sips -z 192 192 "$ICON/app_icon_1024.jpg" --out "$WEB/icons/Icon-192.png" >/dev/null
sips -z 32 32 "$ICON/app_icon_1024.jpg" --out "$WEB/favicon.png" >/dev/null
sips -z 512 512 "$ICON/app_icon_maskable_1024.jpg" --out "$WEB/icons/Icon-maskable-512.png" >/dev/null
sips -z 192 192 "$ICON/app_icon_maskable_1024.jpg" --out "$WEB/icons/Icon-maskable-192.png" >/dev/null

echo "Web icons resized."
