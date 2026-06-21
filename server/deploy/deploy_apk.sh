#!/usr/bin/env bash
# 上传 Android APK 到 tanmystudio.site/downloads/
#
# 用法：
#   bash server/deploy/deploy_apk.sh [apk路径] [远端文件名]
#
# 示例：
#   bash server/deploy/deploy_apk.sh                          # 废话预言家默认
#   bash server/deploy/deploy_apk.sh ./app.apk daily-page-arm64-v8a.apk
#   bash server/deploy/deploy_apk.sh ./app.apk mindrise-arm64-v8a.apk

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APK="${1:-${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"
REMOTE_NAME="${2:-nonsense-prophet-arm64-v8a.apk}"
HOST="${DEPLOY_HOST:-175.178.249.107}"
USER="${DEPLOY_USER:-ubuntu}"
REMOTE_DIR="/var/www/tanmystudio.site/downloads"

if [[ ! -f "${APK}" ]]; then
  echo "找不到 APK: ${APK}" >&2
  echo "请先构建 APK，或传入正确路径。" >&2
  exit 1
fi

echo ">>> 上传 ${APK} → ${USER}@${HOST}:${REMOTE_DIR}/${REMOTE_NAME}"
ssh "${USER}@${HOST}" "sudo mkdir -p ${REMOTE_DIR} && sudo chown ${USER}:${USER} ${REMOTE_DIR}"
scp "${APK}" "${USER}@${HOST}:/tmp/${REMOTE_NAME}"
ssh "${USER}@${HOST}" bash -s <<EOF
set -euo pipefail
sudo mv /tmp/${REMOTE_NAME} ${REMOTE_DIR}/${REMOTE_NAME}
sudo chown www-data:www-data ${REMOTE_DIR}/${REMOTE_NAME}
ls -lh ${REMOTE_DIR}/${REMOTE_NAME}
EOF

echo ""
echo -n "验证: "
curl -sS -m 10 -o /dev/null -w "HTTP %{http_code}\n" \
  "https://tanmystudio.site/downloads/${REMOTE_NAME}" || true
echo "下载页: https://tanmystudio.site/"
