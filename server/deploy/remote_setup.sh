#!/usr/bin/env bash
# 在腾讯云 VM 上执行：安装目录 /opt/nonsense-prophet-proxy/server
# 代码来源（任选其一，见下方）：
#   1) 本机 scp 上传 tarball 到 /tmp/nonsense-prophet-server.tar.gz 后运行本脚本
#   2) Git：若仓库已包含 server/，设置 GIT_REPO_URL 后运行（当前 MVP 可能尚未提交 server/）
#
# 用法：
#   bash remote_setup.sh
#   GIT_REPO_URL=https://github.com/OWNER/REPO.git bash remote_setup.sh

set -euo pipefail

INSTALL_ROOT="/opt/nonsense-prophet-proxy"
SERVER_DIR="${INSTALL_ROOT}/server"
TARBALL="/tmp/nonsense-prophet-server.tar.gz"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未安装 Docker。请先安装 Docker CE 与 compose 插件。" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "错误: 未找到 docker compose 插件。" >&2
  exit 1
fi

sudo mkdir -p "${INSTALL_ROOT}"
sudo chown "${USER}:${USER}" "${INSTALL_ROOT}"

if [[ -n "${GIT_REPO_URL:-}" ]]; then
  if [[ ! -d "${INSTALL_ROOT}/.git" ]]; then
    git clone "${GIT_REPO_URL}" "${INSTALL_ROOT}"
  else
    git -C "${INSTALL_ROOT}" pull --ff-only
  fi
  if [[ ! -d "${SERVER_DIR}" ]]; then
    echo "错误: 克隆后不存在 ${SERVER_DIR}，请确认仓库内含 server/ 目录。" >&2
    exit 1
  fi
elif [[ -f "${TARBALL}" ]]; then
  mkdir -p "${SERVER_DIR}"
  tar -xzf "${TARBALL}" -C "${SERVER_DIR}"
  rm -f "${TARBALL}"
elif [[ -f "${SERVER_DIR}/docker-compose.prod.yml" ]]; then
  echo "使用已有目录 ${SERVER_DIR}"
else
  echo "错误: 未找到代码。请在本机执行 scp 上传 tarball 或 server/ 目录，或设置 GIT_REPO_URL。" >&2
  echo "  scp 示例（在本机 Mac 终端，会提示输入 ubuntu 密码）：" >&2
  echo "    scp /tmp/nonsense-prophet-server.tar.gz ubuntu@175.178.249.107:/tmp/" >&2
  exit 1
fi

cd "${SERVER_DIR}"

if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo ""
  echo ">>> 请编辑 ${SERVER_DIR}/.env ，设置 DEEPSEEK_API_KEY=... 后再运行："
  echo "    nano .env"
  echo "    docker compose -f docker-compose.prod.yml up -d --build"
  echo ""
  exit 0
fi

if ! grep -q '^DEEPSEEK_API_KEY=.\+' .env 2>/dev/null; then
  echo "错误: .env 中 DEEPSEEK_API_KEY 为空。请 nano .env 填写后重试。" >&2
  exit 1
fi

docker compose -f docker-compose.prod.yml up -d --build

echo ""
echo "健康检查（本机）："
curl -sf "http://127.0.0.1/health" | python3 -m json.tool || {
  echo "健康检查失败，查看日志: docker compose -f docker-compose.prod.yml logs -f app" >&2
  exit 1
}
