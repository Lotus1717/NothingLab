# IP 直连部署指南（MVP）

适用于：**无域名、无 Redis**，在腾讯云轻量服务器上通过公网 IP 暴露 HTTP 服务。

**目标服务器**：`175.178.249.107`（广州，Docker CE 27.5）  
**安全组已放行**：22（SSH）、80（HTTP）、443（HTTPS，后续 SSL 用）

> 本文档不含任何密码或 API Key，请自行在服务器上配置。

---

## 1. 前置条件

- 本机可 SSH 登录服务器（密钥或密码由你保管）
- 服务器已安装 Docker 与 Docker Compose 插件
- 已准备好 [DeepSeek API Key](https://platform.deepseek.com/)

验证 Docker（在服务器上执行）：

```bash
docker --version
docker compose version
```

---

## 2. 上传代码

任选一种方式将 `server/` 目录放到服务器，例如 `/opt/nonsense-prophet-proxy/server`。

### 方式 A：Git 克隆（推荐）

```bash
ssh root@175.178.249.107

sudo mkdir -p /opt/nonsense-prophet-proxy
sudo chown $USER:$USER /opt/nonsense-prophet-proxy
cd /opt/nonsense-prophet-proxy

git clone <你的仓库地址> .
cd server
```

### 方式 B：本机 scp 上传

在本机项目根目录执行：

```bash
scp -r server/ root@175.178.249.107:/opt/nonsense-prophet-proxy/server
```

然后在服务器上：

```bash
ssh root@175.178.249.107
cd /opt/nonsense-prophet-proxy/server
```

---

## 3. 配置环境变量

```bash
cp .env.example .env
chmod 600 .env
nano .env   # 或 vim .env
```

**最少只需设置一项**：

```env
DEEPSEEK_API_KEY=你的_deepseek_key
```

`docker-compose.prod.yml` 已配置：

- `SQLITE_PATH=/data/quota.db`（配额持久化）
- 端口映射 `80:8000`（公网直接访问，无需 Nginx）
- 命名卷 `quota_data` 挂载到容器 `/data`

---

## 4. 构建并启动

```bash
cd /opt/nonsense-prophet-proxy/server
docker compose -f docker-compose.prod.yml up -d --build
```

查看状态与日志：

```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f app
```

---

## 5. 健康检查

在服务器上：

```bash
curl -s http://127.0.0.1/health | python3 -m json.tool
```

在本机或任意可访问公网的机器：

```bash
curl -s http://175.178.249.107/health | python3 -m json.tool
```

期望响应示例：

```json
{
  "status": "ok",
  "deepseek_configured": true,
  "storage_ok": true
}
```

若 `status` 为 `degraded`，检查 `.env` 中 `DEEPSEEK_API_KEY` 是否已填写并重启容器。

---

## 6. 功能冒烟测试

**一键自动测试（在本机执行，无需 SSH）**：

```bash
# 完整测试（含 1 次真实生成，消耗配额）
bash server/deploy/smoke_test.sh

# 只测连通性与校验，不扣配额
SMOKE_SKIP_PROPHECY=1 bash server/deploy/smoke_test.sh
```

手动 curl 示例：

查询配额（不消耗次数）：

```bash
curl -s "http://175.178.249.107/v1/quota?device_id=test-device-smoke-001"
```

生成预言（成功时消耗 1 次配额）：

```bash
curl -s -X POST http://175.178.249.107/v1/prophecy \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-smoke-001",
    "nonce": 1,
    "sensor": {
      "battery": 72,
      "brightness": 55,
      "volume": 30,
      "steps": 1234,
      "is_moving": false,
      "ambient_light": 120,
      "is_estimated_ambient_light": true,
      "day_phase": "下午",
      "time_hint": "下午摸鱼中"
    }
  }'
```

---

## 7. 更新部署

```bash
cd /opt/nonsense-prophet-proxy/server
git pull   # 若使用 git
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

---

## 8. HTTPS（tanmystudio.site）

域名 **tanmystudio.site** 已备案/解析后，按 **[DEPLOY_HTTPS.md](./DEPLOY_HTTPS.md)** 安装腾讯云 SSL 证书与 Nginx。

简要步骤：compose 改 `127.0.0.1:8000:8000` → 上传证书 → 启用 `nginx-tanmystudio.site.conf` → `curl https://tanmystudio.site/health`。

---

## 9. iOS / 客户端注意事项

| 场景 | 说明 |
|------|------|
| **IP + HTTP** | MVP 可用；Flutter 开发阶段可临时允许明文 HTTP |
| **iOS ATS** | 正式发布需 HTTPS 域名，或在 Info.plist 为特定 IP 添加 ATS 例外（仅内测） |
| **生产** | `https://tanmystudio.site`（见 DEPLOY_HTTPS.md） |

---

## 10. 数据备份

配额库位于 Docker 卷 `quota_data`，容器内路径 `/data/quota.db`。

查看卷名：

```bash
docker volume ls | grep quota
```

备份示例（将 `VOLUME_NAME` 替换为实际卷名）：

```bash
docker run --rm -v VOLUME_NAME:/data -v $(pwd):/backup alpine \
  cp /data/quota.db /backup/quota.db.bak
```

---

## 11. 故障排查

| 现象 | 处理 |
|------|------|
| `curl` 连接超时 | 检查安全组 80 是否对 `0.0.0.0/0` 开放 |
| `storage_ok: false` | `docker compose logs app` 查看 SQLite 权限；确认 `/data` 卷已挂载 |
| `deepseek_configured: false` | 检查 `.env` 中 `DEEPSEEK_API_KEY` |
| 502 预言失败 | DeepSeek 侧限流或 Key 无效；查 `docker compose logs app` |
| 429 配额用尽 | 正常；次日 `Asia/Shanghai` 零点重置，或换 `device_id` 测试 |

---

*文档随 `server/` 代码更新；完整架构见 [`docs/DEEPSEEK_PROXY.md`](../../docs/DEEPSEEK_PROXY.md)。*
