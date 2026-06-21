# HTTPS 部署指南 · tanmystudio.site

域名：**tanmystudio.site**  
服务器：**175.178.249.107**（腾讯云轻量，广州）  
证书安装参考：[腾讯云 Nginx 证书安装](https://cloud.tencent.com/document/product/1207/47027)

---

## ⚠️ 别搞混两种「证书」

| 类型 | 是什么 | 能否装 HTTPS |
|------|--------|--------------|
| **域名证书** | DNSPod 发的注册证明（如 `notes/tanmystudio.site.jpg` 截图） | ❌ 不能 |
| **SSL 证书** | [SSL 证书控制台](https://console.cloud.tencent.com/ssl) 申请，下载 **Nginx** 压缩包，含 `.crt` + `.key` | ✅ 用这个 |

域名证书只证明你拥有 `tanmystudio.site`；Nginx 需要的是 **SSL/TLS 证书文件**。

---

## 1. DNS 解析

在域名服务商添加 **A 记录**：

| 主机记录 | 记录类型 | 记录值 |
|----------|----------|--------|
| `@` | A | `175.178.249.107` |

可选：若需 `www.tanmystudio.site`，再加一条 A 记录或 CNAME。

验证（本机执行，解析生效后）：

```bash
dig +short tanmystudio.site
# 应返回 175.178.249.107
```

---

## 2. 申请 SSL 证书

1. 登录 [腾讯云 SSL 证书控制台](https://console.cloud.tencent.com/ssl)
2. 申请免费证书，绑定域名 **`tanmystudio.site`**
3. 完成域名验证后，下载 **Nginx** 格式压缩包
4. 解压得到（文件名以实际为准）：
   - `tanmystudio.site_bundle.crt`
   - `tanmystudio.site.key`
5. 将两个文件放到本机 `server/deploy/ssl/`（该目录已 gitignore，**勿提交私钥**）  
   或从 `daily_page_app/notes/tanmystudio.site_nginx/` 复制（该目录也已 gitignore）

**一键部署**（上传证书 + 改 Docker + 装 Nginx）：

```bash
bash server/deploy/deploy_ssl.sh
```

手动上传：

```bash
scp server/deploy/ssl/tanmystudio.site_bundle.crt \
    server/deploy/ssl/tanmystudio.site.key \
    ubuntu@175.178.249.107:/tmp/
```

---

## 3. 调整 Docker（释放 80/443 给 Nginx）

SSH 登录服务器：

```bash
ssh root@175.178.249.107
cd /opt/nonsense-prophet-proxy/server
```

编辑 `docker-compose.prod.yml`，将端口映射改为仅本机：

```yaml
ports:
  - "127.0.0.1:8000:8000"
```

重启：

```bash
docker compose -f docker-compose.prod.yml up -d
curl -s http://127.0.0.1:8000/health | python3 -m json.tool
```

---

## 4. 安装 Nginx 与证书

```bash
sudo apt update && sudo apt install -y nginx

sudo mkdir -p /etc/nginx/ssl
sudo cp tanmystudio.site_bundle.crt /etc/nginx/ssl/
sudo cp tanmystudio.site.key /etc/nginx/ssl/
sudo chmod 600 /etc/nginx/ssl/tanmystudio.site.key

sudo cp /opt/nonsense-prophet-proxy/server/deploy/nginx-tanmystudio.site.conf \
  /etc/nginx/sites-available/tanmystudio.site
sudo ln -sf /etc/nginx/sites-available/tanmystudio.site /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl reload nginx
```

确认防火墙 / 安全组已放行 **443**（当前文档记载已开放）。

---

## 5. 备案首页（静态）

`https://tanmystudio.site/` 展示简短说明页；`/health`、`/v1/*` 仍反代 API。

```bash
bash server/deploy/deploy_site.sh
```

拾页隐私说明等 HTML 放到 `server/deploy/www/`（如 `privacy.html` → `https://tanmystudio.site/privacy.html`），再执行上述脚本。

首页应用卡片与 Android 包：

- 编辑 `server/deploy/www/index.html`（卡片、iOS App Store 链接见页内 `IOS_APP_STORE_URL`）
- APK 上传：`bash server/deploy/deploy_apk.sh`（见 `server/deploy/www/downloads/README.md`）

---

## 6. 验证 HTTPS

```bash
curl -s https://tanmystudio.site/health | python3 -m json.tool
curl -s https://tanmystudio.site/ | head -5
```

本机冒烟测试：

```bash
SMOKE_BASE_URL=https://tanmystudio.site bash server/deploy/smoke_test.sh
```

---

## 7. 客户端已切换

拾页 App `ServerConfig.baseUrl` 已改为 `https://tanmystudio.site`，Info.plist 已移除 HTTP ATS 例外。

**状态**：✅ 2026-06-09 已部署，`curl https://tanmystudio.site/health` 返回 `status: ok`。

---

## 8. 证书续期

腾讯云免费证书有效期约 1 年。到期前在控制台重新申请，替换 `/etc/nginx/ssl/` 下文件后执行：

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## 故障排查

| 现象 | 处理 |
|------|------|
| `curl` 证书错误 | 检查证书文件名是否与 nginx 配置一致 |
| 502 Bad Gateway | `docker compose ps` 确认容器在跑；`curl http://127.0.0.1:8000/health` |
| HTTP 仍可访问但不跳转 | 检查 80 端口的 `return 301` server 块 |
| App 连不上 | 确认 HTTPS 已通；真机日期时间正确 |
