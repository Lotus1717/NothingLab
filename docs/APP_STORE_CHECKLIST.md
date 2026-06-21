# App Store 上架清单 · 废话预言家

**文档类型**：上架前操作清单  
**最后更新**：2026-06-21  
**版本参考**：1.0.0（`pubspec.yaml` / `lib/config/app_version.dart`）

---

## 概览

上架流程分四段：**账号与标识 → 工程与合规 → TestFlight 内测 → 正式提审**。  
内测不必填完整商店截图，但 **App ID + App Store Connect App 记录** 必须先有。

推荐顺序：

```
Apple Developer 账号
    → 注册 App ID（Bundle ID）
    → App Store Connect 创建 App
    → 签名打包上传 TestFlight
    → 补全商店素材与隐私问卷
    → 提交审核
```

---

## 一、已完成 ✅

| 项目 | 说明 |
|------|------|
| **Bundle ID** | `site.tanmystudio.nonsenseprophet`（iOS / macOS / Android `applicationId`） |
| **签名 Team** | Xcode `DEVELOPMENT_TEAM = P8Y93CNFAU`，Automatic Signing |
| **ExportOptions** | `ios/ExportOptions.plist`（App Store Connect 导出） |
| **出口合规** | `ios/Runner/Info.plist` → `ITSAppUsesNonExemptEncryption = false` |
| **隐私政策** | `server/deploy/www/privacy.html`，线上 https://tanmystudio.site/privacy.html |
| **备案首页** | https://tanmystudio.site/ ，底部已链到隐私政策 |
| **运动权限文案** | `NSMotionUsageDescription`（步数/传感器） |
| **Onboarding** | 首次启动三页引导 |
| **HTTPS 代理** | 客户端 `ProxyConfig.baseUrl = https://tanmystudio.site` |
| **App 图标** | `flutter_launcher_icons` 已配置 1024 素材 |

---

## 二、待办清单

### 2.1 账号与标识（内测前必做）

- [ ] **Apple Developer 账号**有效（$99/年）
- [ ] **注册 App ID**  
  - 路径：[Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)  
  - Identifier：`site.tanmystudio.nonsenseprophet`  
  - 或在 Xcode → Signing & Capabilities → 首次 Archive 时由 Automatic Signing 自动创建
- [ ] **App Store Connect 创建 App**  
  - 路径：[App Store Connect](https://appstoreconnect.apple.com) → 我的 App → ＋  
  - 名称：废话预言家  
  - Bundle ID：选 `site.tanmystudio.nonsenseprophet`  
  - 主要语言：简体中文  
  - 类别建议：娱乐 / 生活方式  

> **说明**：TestFlight 内测也需要 Connect 里的 App 记录；不必先填截图和完整描述。

### 2.2 签名与打包

- [ ] Xcode 打开 `ios/Runner.xcworkspace`，确认 Signing 无报错
- [ ] 本地自检：

```bash
flutter analyze
flutter test
```

- [ ] 打 Release IPA 并上传：

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

- [ ] 用 **Transporter** 或 Xcode **Organizer → Distribute App** 上传到 App Store Connect
- [ ] 等待处理（通常 10–30 分钟）→ **TestFlight** 添加内部测试员

**真机调试（非 TestFlight）** 可直接：

```bash
flutter run --release -d <设备 ID>
```

### 2.3 App Store Connect 元数据（正式提审前必做）

| 字段 | 建议内容 |
|------|----------|
| **隐私政策 URL** | https://tanmystudio.site/privacy.html |
| **支持 URL** | https://tanmystudio.site |
| **副标题** | 传感器编无厘头神谕（≤30 字，按实际上线文案调整） |
| **描述** | 戳小猫 → 读传感器 → AI/模板生成废话 → 收藏/分享图 |
| **关键词** | 预言,传感器,摸鱼,分享,趣味 等 |
| **截图** | 至少 6.7" + 6.5" iPhone；建议含 onboarding、首页、预言卡、分享图 |
| **App 图标** | 1024×1024，无透明、无圆角 |

### 2.4 App 隐私问卷（App Privacy）

按 App 实际行为填写（与 `privacy.html` 一致）：

| 数据类型 | 是否收集 | 用途 |
|----------|----------|------|
| 设备 ID | 是 | 服务端每日配额（`device_id`） |
| 健康与健身（步数） | 可选 | 本地读取，摘要上传生成预言 |
| 其他传感器数据 | 是 | 电量、亮度、音量等编进预言 |
| 用户内容（收藏） | 是 | **仅本地**，不上传 |
| 分析/追踪 | 否 | `AnalyticsService` 仅本地计数 |
| 广告 / IDFA | 否 | 无需 ATT 弹窗 |

### 2.5 审核备注（Review Notes 建议）

```
- 无需登录账号
- 默认走云端 AI（https://tanmystudio.site），每设备每日 50 次
- 配额用尽或离线时自动使用内置模板库，仍可戳猫出预言
- 运动/传感器权限可选；拒绝后使用模拟数据，核心功能可用
- 审核期间请确保服务端可访问
```

### 2.6 工程与产品（建议，非阻塞内测）

- [ ] **分享图二维码落地页**  
  `lib/config/share_config.dart` → `ShareConfig.landingUrl`  
  上架后改为 App Store 链接或官网
- [ ] **Privacy Manifest**  
  补充 `ios/Runner/PrivacyInfo.xcprivacy`（2024 年起第三方 SDK 要求；检查 Pods 是否已自带）
- [ ] **推送权限说明**  
  用户主动开启「每日提醒」时才请求；Connect 隐私问卷中如实填写
- [ ] **Release 自测**  
  无权限路径、配额用尽降级、分享图、收藏、onboarding 跳过

### 2.7 静态页更新（可选）

修改 `server/deploy/www/` 后重新部署：

```bash
bash server/deploy/deploy_site.sh
```

---

## 三、内测 vs 正式上架

| 项目 | TestFlight 内测 | App Store 正式上架 |
|------|-----------------|---------------------|
| App ID | ✅ 必须 | ✅ 必须 |
| Connect App 记录 | ✅ 必须 | ✅ 必须 |
| 上传签名 IPA | ✅ 必须 | ✅ 必须 |
| 截图 / 完整描述 | ❌ 不必 | ✅ 必须 |
| App 隐私问卷 | 建议先填 | ✅ 必须 |
| 年龄分级 | 建议先填 | ✅ 必须 |
| 审核 | 内部测试免审；外部测试需 Beta 审 | ✅ App Review |

**内部测试员**：App Store Connect 用户角色为 Admin/App Manager 等，最多 100 人，构建处理完即可安装。

---

## 四、常用命令

```bash
# 静态页 / 隐私政策部署
bash server/deploy/deploy_site.sh

# 验证隐私页
curl -sI https://tanmystudio.site/privacy.html | head -1

# 验证 API
curl -s https://tanmystudio.site/health | python3 -m json.tool

# iOS Release IPA
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# 冒烟测试（HTTPS）
SMOKE_BASE_URL=https://tanmystudio.site bash server/deploy/smoke_test.sh
```

---

## 五、相关文件索引

| 文件 | 用途 |
|------|------|
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle ID、DEVELOPMENT_TEAM |
| `ios/ExportOptions.plist` | App Store 导出配置 |
| `ios/Runner/Info.plist` | 权限文案、出口合规 |
| `lib/config/proxy_config.dart` | 云端 API 地址 |
| `lib/config/share_config.dart` | 分享图二维码落地页 |
| `server/deploy/www/privacy.html` | 隐私政策源文件 |
| `server/deploy/deploy_site.sh` | 静态站部署脚本 |
| `server/deploy/DEPLOY_HTTPS.md` | HTTPS / Nginx 部署说明 |

---

## 六、费用与时间预期

- **Developer 程序**：$99/年  
- **服务器**：已有 `tanmystudio.site`  
- **首次提审到上架**：材料齐备后通常 3–7 天（含可能的拒审修改）

---

## 七、故障排查

| 现象 | 处理 |
|------|------|
| Xcode Signing 报错 | 确认 Developer 后台已注册 App ID；Team 选对 |
| 上传失败「No suitable application records」 | 先在 App Store Connect 创建 App，Bundle ID 一致 |
| 审核时云端不可用 | 确认 `https://tanmystudio.site/health` 正常；备注说明模板库兜底 |
| 502 / 配额 | 见 `server/deploy/DEPLOY_IP.md` 故障表 |

---

Built with ❤️ by Lotus · 与 `docs/PRODUCT.md` 互补（产品评估 vs 上架操作）
