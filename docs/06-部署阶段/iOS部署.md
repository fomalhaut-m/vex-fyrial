# iOS 部署手册

> **文档状态**：待补充
> **最后更新**：2026-05-10

---

## 1. 概述

本文档描述 Vexfy iOS 应用的部署流程，包括证书配置、TestFlight 和 App Store 上架。

---

## 2. 环境要求

| 项目 | 要求 |
|------|------|
| Xcode | 15.0+ |
| iOS Deployment Target | 14.0 |
| Swift | 5.9+ |
| Flutter SDK | 3.19+ |

---

## 3. 证书配置

### 3.1 Apple Developer 账号

- **个人/公司账号**：年费 $99，用于 App Store 上架
- **企业账号**：年费 $299，用于内部分发（In-House）

### 3.2 证书类型

| 证书 | 用途 | 有效期 |
|------|------|--------|
| iOS Development | 本地开发调试 | 1 年 |
| iOS Distribution | App Store / Ad-Hoc / In-House | 1 年 |
| Apple Push Notification service (APNs) | 推送通知 | 1 年 |

### 3.3 创建流程

1. 登录 [Apple Developer Console](https://developer.apple.com)
2. 创建 App ID（Bundle Identifier：`com.vexfy.app`）
3. 创建Provisioning Profile
4. 下载证书并导入钥匙串

---

## 4. Xcode 配置

### 4.1 Runner 项目设置

```
Xcode → Runner → Signing & Capabilities
- Team: 选择开发团队
- Bundle Identifier: com.vexfy.app
- Version: 1.0.0
- Build: 1
```

### 4.2 Capabilities

| Capability | 用途 |
|------------|------|
| Background Modes → Audio | 后台音频播放 |
| Push Notifications | 推送通知（待实现） |
| App Groups | 跨 App 数据共享（如有） |

### 4.3 Info.plist 关键配置

```xml
<!-- 后台音频模式 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- 隐私描述 -->
<key>NSAppleMusicUsageDescription</key>
<string>Vexfy 需要访问您的音乐库以播放本地音乐</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Vexfy 需要访问本地网络以发现音乐设备</string>
```

---

## 5. 构建与导出

### 5.1 命令行构建

```bash
# Debug 构建（用于模拟器测试）
flutter build ios --debug

# Release 构建（用于真机/商店）
flutter build ios --release
```

### 5.2 Archive 导出

```bash
# 打开 Xcode
open ios/Runner.xcworkspace

# Xcode 菜单：Product → Archive
# 导出后选择：
# - App Store Connect（上传到 App Store）
# - Ad Hoc（指定设备分发）
# - Enterprise（In-House 企业分发）
```

---

## 6. TestFlight 上架

### 6.1 上传构建

使用 Xcode 或 Transporter App 上传 `.ipa` 或 `.app` 文件到 App Store Connect。

### 6.2 TestFlight 流程

1. **构建上传**：上传后等待 10-30 分钟处理
2. **自动测试**：App Store Connect 自动检测过审状态
3. **添加测试员**：
   - **内部测试员**：Apple Developer 团队成员，即时可用
   - **外部测试员**：需要通过 Beta 版审核（约 24-48 小时）
4. **测试反馈**：测试员可通过 TestFlight App 提交反馈

### 6.3 必填信息

| 字段 | 说明 |
|------|------|
| 新版本号 | 需大于已上架版本 |
| 测试说明 | 描述本次构建的测试重点 |
| 联系邮箱 | 供测试员反馈问题 |

---

## 7. App Store 上架

### 7.1 App Store Connect 配置

| 项目 | 要求 |
|------|------|
| 应用名称 | Vexfy |
| 副标题 | 本地音乐 + OSS 双向同步播放器 |
| 关键词 | 本地音乐,OSS,播放器,FLAC,无损音乐 |
| 描述 | 详细描述应用功能（需通过审核指南） |
| 价格 | 免费 / 付费 |
| 分级 | 4+（音乐播放，无年龄限制内容） |
| 截图 | iPhone 6.7"/6.5"/5.5" 截图各一套 |
| 应用预览视频 | 可选（强烈推荐） |

### 7.2 审核时长

- **首次上架**：约 1-2 周
- **更新版本**：约 1-3 天

### 7.3 常见拒绝原因

- 后台音频未正确配置 `UIBackgroundModes`
- 隐私政策 URL 不可访问或内容不完整
- 应用截图与实际 UI 不符
- 包含未说明的第三方 SDK 数据收集

---

## 8. Flutter iOS 特定注意事项

### 8.1 on_audio_query

- `on_audio_query` 在 iOS 上依赖 MPMediaQuery
- iOS 14+ 需在 Info.plist 添加 `NSAppleMusicUsageDescription`

### 8.2 just_audio

- `just_audio` 在 iOS 使用 AVPlayer，无需额外 Platform Channel
- 后台播放需开启 Background Modes → Audio

### 8.3 flutter_secure_storage

- iOS 使用 Keychain，配置正确则无需额外设置

---

## 9. 版本管理

| 字段 | 说明 |
|------|------|
| CFBundleVersion | Build 号（每次上传必须递增） |
| CFBundleShortVersionString | 展示版本号（如 1.0.0） |

---

_本文档待补充更多细节_
