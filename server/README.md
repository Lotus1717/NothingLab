# 废话预言家 · DeepSeek 代理服务（MVP）

为 Flutter 客户端提供安全的 DeepSeek 调用，API Key 仅存服务端，配额由 **SQLite** 按 `device_id` 每日计数。

**本服务同时为两个 App 提供 API：**

| App | 路由 |
|-----|------|
| 废话预言家 | `/v1/prophecy`、`/v1/quota`、`/v1/register` |
| [拾页](../daily_page_app/) | `/v1/daily-page`、`/v1/weread/sync`、`/v1/reflection-prompt` |

拾页 Flutter 客户端见 `daily_page_app/`，**勿在拾页项目内维护重复 server 代码**。

## 快速开始（本地）

```bash
cd server
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY

docker compose up -d --build
curl http://localhost:8000/health
```

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/health` | 健康检查 |
| `POST` | `/v1/prophecy` | 生成预言（**成功时**消耗配额） |
| `GET` | `/v1/quota?device_id=` | 查询当日配额 |
| `POST` | `/v1/register` | 可选设备注册 |
| `POST` | `/v1/daily-page` | 拾页：生成书摘（`nonce=0` 消耗配额，换书不扣） |
| `POST` | `/v1/weread/sync` | 拾页：同步微信读书书架 |
| `POST` | `/v1/reflection-prompt` | 拾页：AI 引导提问（不扣配额） |

### POST /v1/prophecy

```json
{
  "device_id": "your-stable-device-uuid",
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
}
```

成功响应 `200`：

```json
{
  "prophecy": "电量72%时，你的拇指会比平时多划半屏",
  "engine": "deepseek",
  "quota_used": 1,
  "quota_remaining": 49,
  "daily_limit": 50
}
```

配额用尽返回 `429`。DeepSeek 调用失败返回 `502`，**不扣配额**。

## 环境变量

| 变量 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `DEEPSEEK_API_KEY` | 是 | — | DeepSeek API 密钥 |
| `SQLITE_PATH` | 否 | `./data/quota.db` | SQLite 数据库文件路径 |
| `DATA_DIR` | 否 | — | 数据目录（使用 `{DATA_DIR}/quota.db`） |
| `DAILY_LIMIT` | 否 | `50` | 每设备每日上限 |
| `QUOTA_TIMEZONE` | 否 | `Asia/Shanghai` | 配额自然日时区 |
| `REGISTER_API_KEY` | 否 | — | 设置后注册接口需 Bearer |

Docker Compose 默认 `SQLITE_PATH=/data/quota.db` 并挂载 `quota_data` 卷。

## 生产部署

- **IP 直连 MVP**：见 [`deploy/DEPLOY_IP.md`](deploy/DEPLOY_IP.md)（`docker-compose.prod.yml` 映射 `80:8000`）
- **域名 + HTTPS**：见仓库 [`docs/DEEPSEEK_PROXY.md`](../docs/DEEPSEEK_PROXY.md)

简要流程：

1. 购买轻量应用服务器（Ubuntu 22.04）
2. 安全组放行 80/443，SSH 限制来源 IP
3. 安装 Docker / Docker Compose，上传 `server/` 目录
4. 创建 `.env`（`chmod 600`），填入 `DEEPSEEK_API_KEY`
5. `docker compose -f docker-compose.prod.yml up -d --build`
6. `curl http://<公网IP>/health`

## 开发（无 Docker）

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export DEEPSEEK_API_KEY=your_key
mkdir -p data
uvicorn app.main:app --reload --port 8000
```

## 测试

单元测试（本地，不访问公网）：

```bash
cd server
python -m pytest tests/ -v --ignore=tests/test_remote_smoke.py
```

远程冒烟测试（一键验证公网代理，**成功时会消耗 1 次配额**）：

```bash
# 方式 A：Shell 脚本（推荐，仅需 curl）
bash server/deploy/smoke_test.sh

# 不测生成、不扣配额
SMOKE_SKIP_PROPHECY=1 bash server/deploy/smoke_test.sh

# 方式 B：pytest
cd server
SMOKE_BASE_URL=http://175.178.249.107 python -m pytest tests/test_remote_smoke.py -v
```

## 安全提示

- **永远不要**将 `DEEPSEEK_API_KEY` 写入代码或提交 Git
- 生产 `.env` 权限设为 `600`
- 客户端后续应改为调用本代理，不再内置 Key
