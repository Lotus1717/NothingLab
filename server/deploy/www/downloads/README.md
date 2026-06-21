# Android 安装包

首页各 App 的「Android 下载」链接：

| App | 文件名 |
|-----|--------|
| 废话预言家 | `/downloads/nonsense-prophet-arm64-v8a.apk` |
| 拾页 | `/downloads/daily-page-arm64-v8a.apk` |
| 念起 | `/downloads/mindrise-arm64-v8a.apk` |

## 构建

**废话预言家 / 拾页（Flutter）**

```bash
cd nonsense_prophet_app   # 或 daily_page_app
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**念起（Capacitor）**

```bash
cd mindrise
npm run cap:sync
cd android && ./gradlew assembleRelease
# 产物：android/app/build/outputs/apk/release/app-arm64-v8a-release.apk
```

## 上传到服务器

废话预言家：

```bash
bash server/deploy/deploy_apk.sh [apk路径] nonsense-prophet-arm64-v8a.apk
```

拾页 / 念起（指定本地 APK 与远端文件名）：

```bash
bash server/deploy/deploy_apk.sh \
  /path/to/app-arm64-v8a-release.apk \
  daily-page-arm64-v8a.apk

bash server/deploy/deploy_apk.sh \
  /path/to/app-arm64-v8a-release.apk \
  mindrise-arm64-v8a.apk
```

或复制到 `server/deploy/www/downloads/` 后：

```bash
bash server/deploy/deploy_site.sh
```

## 验证

```bash
curl -sI https://tanmystudio.site/downloads/daily-page-arm64-v8a.apk | head -1
```
