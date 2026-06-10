#!/usr/bin/env bash
# 上传备案首页等静态页面 + 重载 Nginx
#
# 用法：
#   bash server/deploy/deploy_site.sh
#
# 环境变量：
#   DEPLOY_HOST   默认 175.178.249.107
#   DEPLOY_USER   默认 ubuntu
#   SITE_WWW      默认 server/deploy/www

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WWW="${SITE_WWW:-${ROOT}/deploy/www}"
HOST="${DEPLOY_HOST:-175.178.249.107}"
USER="${DEPLOY_USER:-ubuntu}"
REMOTE_WWW="/var/www/tanmystudio.site"

if [[ ! -f "${WWW}/index.html" ]]; then
  echo "缺少 ${WWW}/index.html" >&2
  exit 1
fi

echo ">>> 上传静态页面到 ${USER}@${HOST}:${REMOTE_WWW} ..."
ssh "${USER}@${HOST}" "sudo mkdir -p ${REMOTE_WWW} && sudo chown ${USER}:${USER} ${REMOTE_WWW} && rm -rf /tmp/tanmystudio-www && mkdir -p /tmp/tanmystudio-www"
scp -r "${WWW}/." "${USER}@${HOST}:/tmp/tanmystudio-www/"
ssh "${USER}@${HOST}" bash -s <<EOF
set -euo pipefail
sudo cp -a /tmp/tanmystudio-www/. ${REMOTE_WWW}/
sudo chown -R www-data:www-data ${REMOTE_WWW}
rm -rf /tmp/tanmystudio-www
echo "静态文件已就位: ${REMOTE_WWW}"
ls -la ${REMOTE_WWW}
EOF

echo ">>> 上传 Nginx 配置 ..."
scp "${ROOT}/deploy/nginx-tanmystudio.site.conf" \
  "${USER}@${HOST}:/tmp/tanmystudio.site.nginx.conf"

echo ">>> 重载 Nginx ..."
ssh "${USER}@${HOST}" bash -s <<'REMOTE'
set -euo pipefail
sudo cp /tmp/tanmystudio.site.nginx.conf /etc/nginx/sites-available/tanmystudio.site
sudo ln -sf /etc/nginx/sites-available/tanmystudio.site /etc/nginx/sites-enabled/tanmystudio.site
sudo nginx -t
sudo systemctl reload nginx
echo "Nginx 已重载"
REMOTE

echo ""
echo ">>> 验证"
echo -n "GET / → "
curl -sS -m 10 -k -o /dev/null -w "HTTP %{http_code}\n" \
  "https://${HOST}/" -H 'Host: tanmystudio.site' || true
echo -n "GET /health → "
curl -sS -m 10 -k -o /dev/null -w "HTTP %{http_code}\n" \
  "https://${HOST}/health" -H 'Host: tanmystudio.site' || true
echo ""
echo "完成。浏览器访问: https://tanmystudio.site/"
