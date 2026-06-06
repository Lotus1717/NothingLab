# 🐣 废话预言家

基于手机传感器 + 本地 AI 模型的无厘头预言 App。

## 特色

- 📱 读取手机传感器（电量、亮度、步数、加速度）
- 🧠 **使用 Apple MLX 框架本地运行 AI 模型**，生成独一无二的预言
- 🎲 每次摇一摇，得到不同的废话
- 📋 历史记录

## 技术栈

- **Flutter** 跨平台框架
- **MLX Swift** — Apple 自家 ML 框架，在 iPhone 本地运行小语言模型
- **传感器**：battery_plus, sensors_plus, pedometer_2, screen_brightness

## 本地运行

### 前置要求

- Flutter SDK 3.27+
- Xcode 16+（iOS 18+）
- 一台 Apple Silicon Mac

### 运行步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 打开 Xcode 工作区（MLX 依赖已写入工程，一般无需手动添加）
open ios/Runner.xcworkspace

# 3. 运行
flutter run
```

### 首次使用

1. 打开 App 后，进入「设置」页
2. 点击「下载 AI 模型（约 200MB）」
3. 等待下载完成（首次仅需一次）
4. 回到首页，戳骰子 🎲

模型会缓存到本地，后续使用无需再次下载。

## 模型说明

使用 **Qwen2.5-0.5B-4bit** 经过 MLX 量化，约 200MB，在 iPhone 上可流畅运行。

生成预言时，模型会根据当前传感器数据，现场编造一句无厘头的中文预言。每次戳出来的都不一样。

---

Built with ❤️ by Lotus
