# 废话预言家

**俏皮神谕 · Playful Oracle** — 读取手机传感器，用 AI 或模板库生成一句无厘头中文预言。

## 简介

打开 App，看看当前电量、步数、音量、环境亮度等传感器读数，**戳一下慵懒小猫（LazyCat）**，就会根据这些数据编出一句独一无二的「废话预言」。喜欢的话可以收藏，或生成分享图发给朋友。

视觉风格温暖极简，带一点仪式感：粉珊瑚 + 薄荷绿渐变、站酷快乐体标题、Oracle 卡片与底部导航。

## 功能

- **戳慵懒小猫**：首页核心交互，加载时小猫耳朵竖起、身后泛起淡金光
- **传感器仪表盘**：首页 `SensorCard` 展示电量、步数、音量、环境亮度与时间提示
- **真/模数据标识**：设置页各传感器项标注「真实数据」或「模拟数据」（权限未授予或不可用时为模拟）
- **多引擎生成**：默认 **云端代理**（`http://175.178.249.107`，服务端持有 DeepSeek 密钥，每设备每日 50 次），超限或失败时自动降级到内置模板库；内部仍保留苹果本地、千问 MLX（iOS）等途径
- **收藏**：底部「收藏」页（`FavoritesPage`）按日期分组，数量不限
- **分享**：预言卡片与收藏页均支持复制、收藏、**生成分享图**（含二维码，`ProphecyShareCard` + 系统分享）；二维码落地页见 `lib/config/share_config.dart`
- **三页导航**：首页 · 收藏 · 设置

## 平台差异

| 能力 | iOS | Android |
|------|-----|---------|
| 苹果本地模型（`flutter_local_ai`） | ✅ 默认首选 | ❌ 不可用，回退模板库 |
| 千问 MLX 内置模型 | ✅ 构建时打包进 App | ❌ MLX 仅 iOS，选项不可用 |
| 云端代理（DeepSeek） | ✅ 默认，服务端代理，每日 50 次 | ✅ 默认，服务端代理，每日 50 次 |
| 模板库 | ✅ 超限/离线回退 | ✅ 超限/离线回退 |
| 传感器 | 电量、步数、加速度、音量、环境光等 | 同上（部分字段可能为模拟） |

**用户预期**：开箱即用云端代理生成（客户端无 API Key）；每日配额用完后静默回退模板库。代理地址可在 `lib/config/proxy_config.dart` 修改。Android 无本地 MLX 千问；iOS 另内置苹果本地与千问 MLX，但默认走云端代理。

## 快速开始

### 前置要求

- Flutter SDK 3.27+（`>=3.0.0`）
- **iOS**：Xcode 16+、Apple Silicon Mac（MLX 构建）
- **Android**：JDK 17、Android SDK

### 安装与运行

```bash
# 安装依赖
flutter pub get

# iOS（首次或模型缺失时，Xcode 构建会自动执行 fetch 脚本）
open ios/Runner.xcworkspace
flutter run

# Android
flutter run
```

### 首次使用

1. 授予运动、健康（步数）等权限（可选，未授予时使用模拟数据）
2. 回首页戳小猫即可（默认云端代理，无需配置 API Key）

## 模型说明

### 生成途径

1. **云端代理**（默认）— `ProphecyProxyClient` 调用服务端 `/v1/prophecy`，密钥仅存服务端，每设备每日 50 次
2. **模板库** — 内置 80+ 条传感器锚定模板；配额用尽、离线或云端失败时自动回退
3. **苹果本地** — Apple 系统本地 AI（`flutter_local_ai`），仅 iOS，内部保留
4. **千问** — Qwen2.5-0.5B-Instruct-4bit，MLX 量化，约 200MB+，**仅 iOS**（代码保留，**默认不打包**）

设置页不再展示引擎切换；用户侧默认 DeepSeek，失败/超限时静默降级。

### 千问模型（可选，默认不打包）

MLX 桥接代码保留于 `ios/Runner/MLProphecyGenerator.swift`，但 Release/Debug 构建**不会**下载或嵌入模型文件，安装包体积不含约 200MB 权重。

需要本地调试千问时（opt-in）：

```bash
BUNDLE_MODEL=1 bash scripts/fetch_bundled_model.sh   # 可设 HF_ENDPOINT 镜像
```

然后在 Xcode 中临时将 `Runner/Models/Qwen2.5-0.5B-Instruct-4bit` 加回 **Copy Bundle Resources**。

## 项目结构

```
lib/
├── main.dart                 # 入口，Provider 注入
├── config/                   # 主题、字体、引擎偏好、DeepSeek 配置、分享落地页
├── models/                   # SensorData、ProphecyRecord
├── screens/
│   ├── home_page.dart        # 首页：LazyCat + 传感器 + 预言卡
│   ├── favorites_page.dart   # 收藏
│   ├── settings_page.dart    # 设置：传感器真/模、清空收藏
│   └── main_screen.dart      # 三页 IndexedStack + 底部导航
├── services/
│   ├── ai_service.dart       # 多引擎调度、收藏、降级
│   ├── sensor_service.dart   # 传感器采集
│   ├── local_ai_bridge.dart  # Apple 本地 AI
│   ├── prophecy_generator.dart # iOS MLX MethodChannel
│   └── deepseek_client.dart  # DeepSeek HTTP
├── widgets/                  # LazyCat、OracleBackground、ProphecyCard 等
└── utils/                    # Prompt、归一化、分享图

ios/Runner/                   # Swift MLX 桥接（模型 opt-in 打包）
scripts/                      # fetch_bundled_model.sh（BUNDLE_MODEL=1）、flutter_env.sh
test/                         # 单元测试与 Widget 测试
docs/                         # 内部产品文档 PRODUCT.md
```

## 测试与构建

```bash
# 静态分析
flutter analyze

# 测试
flutter test

# Release 构建
flutter build ios --release --no-codesign   # iOS
flutter build apk --release --split-per-abi # Android
```

CI：`.github/workflows/build-ios.yml`、`.github/workflows/build-apk.yml`

## 版本

当前版本见 `pubspec.yaml`（`version: 1.0.0+1`）。

### 分享图二维码

分享图底部二维码的落地页 URL 在 `lib/config/share_config.dart` 的 `ShareConfig.landingUrl`（默认 `https://nonsense-prophet.app`），可改为 App Store 或官网链接。

## 许可证

本项目尚未单独声明开源许可证。第三方依赖遵循各自许可证。可选千问模型来自 [mlx-community/Qwen2.5-0.5B-Instruct-4bit](https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit)。

---

Built with ❤️ by Lotus
