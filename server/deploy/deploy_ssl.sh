#!/usr/bin/env bash
# 上传 SSL 证书并配置 Nginx HTTPS（tanmystudio.site）
#
# 用法：
#   bash server/deploy/deploy_ssl.sh
#
# 环境变量：
#   DEPLOY_HOST   默认 175.178.249.107
#   DEPLOY_USER   默认 ubuntu
#   DEPLOY_PATH   默认 /opt/nonsense-prophet-proxy/server
#   SSL_SKIP_DOCKER  设为 1 时跳过改 Docker 端口（已配好时）

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSL_DIR="${ROOT}/deploy/ssl"
HOST="${DEPLOY_HOST:-175.178.249.107}"
USER="${DEPLOY_USER:-ubuntu}"
REMOTE="${DEPLOY_PATH:-/opt/nonsense-prophet-proxy/server}"

CRT="${SSL_DIR}/tanmystudio.site_bundle.crt"
KEY="${SSL_DIR}/tanmystudio.site.key"

for f in "$CRT" "$KEY"; do
  if [[ ! -f "$f" ]]; then
    echo "缺少证书文件: $f" >&2
    echo "请将腾讯云 Nginx 证书放到 server/deploy/ssl/ 后重试" >&2
    exit 1
  fi
done

echo ">>> 上传证书到 ${USER}@${HOST} ..."
ssh "${USER}@${HOST}" "sudo mkdir -p /etc/nginx/ssl && sudo chmod 700 /etc/nginx/ssl"
scp "$CRT" "${USER}@${HOST}:/tmp/tanmystudio.site_bundle.crt"
scp "$KEY" "${USER}@${HOST}:/tmp/tanmystudio.site.key"
ssh "${USER}@${HOST}" bash -s <<'REMOTE_SSL'
set -euo pipefail
sudo mv /tmp/tanmystudio.site_bundle.crt /etc/nginx/ssl/
sudo mv /tmp/tanmystudio.site.key /etc/nginx/ssl/
sudo chmod 644 /etc/nginx/ssl/tanmystudio.site_bundle.crt
sudo chmod 600 /etc/nginx/ssl/tanmystudio.site.key
echo "证书已就位: /etc/nginx/ssl/"
REMOTE_SSL

echo ">>> 上传 Nginx 站点配置 ..."
scp "${ROOT}/deploy/nginx-tanmystudio.site.conf" \
  "${USER}@${HOST}:/tmp/tanmystudio.site.nginx.conf"

if [[ "${SSL_SKIP_DOCKER:-}" != "1" ]]; then
  echo ">>> 调整 Docker 端口为 127.0.0.1:8000（释放 80/443）..."
  ssh "${USER}@${HOST}" bash -s <<EOF
set -euo pipefail
cd "${REMOTE}"
if grep -q '"80:8000"' docker-compose.prod.yml 2>/dev/null; then
  sed -i.bak 's/"80:8000"/"127.0.0.1:8000:8000"/' docker-compose.prod.yml
  echo "compose 端口已改为 127.0.0.1:8000"
fi
sudo docker compose -f docker-compose.prod.yml up -d --force-recreate
echo "等待 Docker 释放 80 端口..."
for i in \$(seq 1 15); do
  if ! sudo ss -tlnp | grep -q ':80 '; then
    break
  fi
  sleep 1
done
if sudo ss -tlnp | grep -q ':80 '; then
  echo "警告: 80 端口仍被占用:" >&2
  sudo ss -tlnp | grep ':80 ' >&2
  exit 1
fi
echo "等待应用就绪 (127.0.0.1:8000)..."
health_ok=0
for i in \$(seq 1 30); do
  if curl -sf http://127.0.0.1:8000/health >/dev/null 2>&1; then
    health_ok=1
    break
  fi
  sleep 1
done
if [[ "\$health_ok" -eq 1 ]]; then
  echo "Docker 健康检查通过 (127.0.0.1:8000)"
else
  echo "警告: 应用尚未响应 /health，继续配置 Nginx（可稍后检查 docker logs）" >&2
fi
EOF
fi

echo ">>> 安装 / 重载 Nginx ..."
ssh "${USER}@${HOST}" bash -s <<'REMOTE_NGINX'
set -euo pipefail
if ! command -v nginx >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi
sudo cp /tmp/tanmystudio.site.nginx.conf /etc/nginx/sites-available/tanmystudio.site
sudo ln -sf /etc/nginx/sites-available/tanmystudio.site /etc/nginx/sites-enabled/tanmystudio.site
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
if sudo systemctl is-active --quiet nginx; then
  sudo systemctl reload nginx
else
  sudo systemctl start nginx
fi
echo "Nginx HTTPS 已启用"
REMOTE_NGINX

echo ""
echo ">>> 验证（需 DNS 已解析 tanmystudio.site → ${HOST}）"
if curl -sf --max-time 10 "https://tanmystudio.site/health" >/dev/null 2>&1; then
  curl -s "https://tanmystudio.site/health" | python3 -m json.tool 2>/dev/null || curl -s "https://tanmystudio.site/health"
  echo ""
  echo "HTTPS 部署成功 ✓"
else
  echo "HTTPS 暂未通（可能 DNS 未生效）。服务器上可测："
  echo "  curl -sk https://127.0.0.1/health -H 'Host: tanmystudio.site'"
  echo "  dig +short tanmystudio.site"
fi
