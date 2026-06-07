#!/usr/bin/env bash
# 本机一键更新 175.178.249.107 上的废话预言家 + 每天拆一页 API
#
# 用法（会提示 SSH 密码，默认用户 ubuntu）：
#   bash server/deploy/deploy_update.sh
#
# 环境变量：
#   DEPLOY_HOST   默认 175.178.249.107
#   DEPLOY_USER   默认 ubuntu
#   DEPLOY_PATH   默认 /opt/nonsense-prophet-proxy/server

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${DEPLOY_HOST:-175.178.249.107}"
USER="${DEPLOY_USER:-ubuntu}"
REMOTE="${DEPLOY_PATH:-/opt/nonsense-prophet-proxy/server}"
TARBALL="/tmp/nonsense-prophet-server-$(date +%s).tar.gz"

echo ">>> 打包 server/ ..."
COPYFILE_DISABLE=1 tar -czf "${TARBALL}" \
  --exclude='.env' \
  --exclude='__pycache__' \
  --exclude='.pytest_cache' \
  --exclude='quota.db' \
  -C "${ROOT}" .

echo ">>> 上传到 ${USER}@${HOST}:/tmp/ ..."
scp "${TARBALL}" "${USER}@${HOST}:/tmp/nonsense-prophet-server.tar.gz"
rm -f "${TARBALL}"

echo ">>> 远程重建 Docker ..."
ssh "${USER}@${HOST}" bash -s <<EOF
set -euo pipefail
sudo mkdir -p "${REMOTE}"
sudo chown "\${USER}:\${USER}" "${REMOTE}"
tar -xzf /tmp/nonsense-prophet-server.tar.gz -C "${REMOTE}"
rm -f /tmp/nonsense-prophet-server.tar.gz
cd "${REMOTE}"
if [[ ! -f .env ]]; then
  echo "错误: ${REMOTE}/.env 不存在，请先在服务器上配置 DEEPSEEK_API_KEY" >&2
  exit 1
fi
sudo docker compose -f docker-compose.prod.yml build
sudo docker compose -f docker-compose.prod.yml up -d
echo ""
echo "等待服务就绪..."
for i in \$(seq 1 20); do
  if curl -sf http://127.0.0.1/health >/dev/null 2>&1; then
    echo "健康检查:"
    curl -sf http://127.0.0.1/health | python3 -m json.tool
    break
  fi
  sleep 1
  if [[ "\$i" -eq 20 ]]; then
    echo "警告: 健康检查超时，请手动执行: sudo docker compose -f docker-compose.prod.yml logs app" >&2
    exit 1
  fi
done
echo ""
echo "daily-page 路由:"
curl -sf -o /dev/null -w "POST /v1/daily-page → HTTP %{http_code}\n" \
  -X POST http://127.0.0.1/v1/daily-page \
  -H 'Content-Type: application/json' \
  -d '{"device_id":"deploy-smoke-test","nonce":999999}' || true
EOF

echo ""
echo ">>> 本机冒烟（daily-page discovery）..."
curl -sS -m 60 -X POST "http://${HOST}/v1/daily-page" \
  -H 'Content-Type: application/json' \
  -d '{"device_id":"deploy-smoke-test-001","nonce":0}' \
  | python3 -m json.tool || echo "（若 404 说明容器尚未加载新路由，请检查 ssh 日志）"

echo ""
echo "完成。App baseUrl: http://${HOST}"
