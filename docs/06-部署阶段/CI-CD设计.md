# CI/CD 设计方案

> **文档状态**：待补充
> **最后更新**：2026-05-10

---

## 1. 概述

本文档描述 Vexfy 项目的持续集成与持续部署（CI/CD）流程设计，包括构建、测试和发布自动化。

---

## 2. CI/CD 目标

| 目标 | 说明 |
|------|------|
| **代码质量门禁** | PR 必须通过静态分析、单元测试、集成测试才能合并 |
| **构建自动化** | 每次 merge 到 main 分支自动构建各平台产物 |
| **发布流程化** | 通过 CI/CD 自动化发布到 TestFlight / Google Play |
| **回滚能力** | 支持快速回滚到上一个稳定版本 |

---

## 3. 技术选型

| 组件 | 选项 | 推荐 |
|------|------|------|
| CI/CD 平台 | GitHub Actions / GitLab CI / Bitrise / Codemagic | GitHub Actions |
| 静态分析 | flutter analyze / dart analyze | flutter analyze |
| 单元测试 | flutter test | flutter test |
| 集成测试 | flutter driver / integration_test | integration_test |
| 崩溃监控 | Firebase Crashlytics / Sentry | Firebase Crashlytics |
| 性能监控 | Firebase Performance | Firebase Performance |

---

## 4. GitHub Actions 工作流

### 4.1 目录结构

```
.github/
└── workflows/
    ├── ci.yml          # PR 检查工作流
    ├── build-android.yml  # Android 构建
    ├── build-ios.yml      # iOS 构建
    └── deploy.yml         # 发布工作流
```

### 4.2 CI 工作流（ci.yml）

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter analyze --no-fatal-infos

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

  android-build:
    runs-on: ubuntu-latest
    needs: [analyze, test]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with:
          name: android-debug
          path: build/app/outputs/flutter-apk/app-debug.apk

  ios-build:
    runs-on: macos-latest
    needs: [analyze, test]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
          architecture: x64
      - run: flutter pub get
      - run: flutter build ios --simulator --no-codesign
```

### 4.3 Android Release 构建（build-android.yml）

```yaml
name: Build Android

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g., 1.0.0)'
        required: true
        type: string
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      - run: flutter pub get
      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: echo $KEYSTORE_BASE64 | base64 -d > vexfy.jks
      - run: |
          echo "storePassword=${{ secrets.STORE_PASSWORD }}" >> key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> key.properties
          echo "storeFile=vexfy.jks" >> key.properties
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v4
        with:
          name: android-release
          path: build/app/outputs/bundle/release/app-release.aab
```

### 4.4 iOS Release 构建（build-ios.yml）

```yaml
name: Build iOS

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g., 1.0.0)'
        required: true
        type: string
  push:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
          architecture: x64
      - run: flutter pub get
      - name: Configure code signing
        run: |
          mkdir -p ios/Runner
          echo "${{ secrets.IOS_CERT_BASE64 }}" | base64 -d > ios/Runner/vexfy.p12
      - name: Import certificate
        run: |
          keychain_id=$(uuidgen)
          security create-keychain -p "" $keychain_id
          security set-keychain-settings $keychain_id
          security unlock-keychain -p "" $keychain_id
          security import ios/Runner/vexfy.p12 -P "${{ secrets.CERT_PASSWORD }}" -A -t cert -f pkcs12 -k $keychain_id
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" $keychain_id
          echo "KEYCHAIN_ID=$keychain_id" >> $GITHUB_ENV
      - run: flutter build ipa --release
      - uses: actions/upload-artifact@v4
        with:
          name: ios-release
          path: build/ios/ipa/vexfy.ipa
```

---

## 5. 分支策略

| 分支 | 用途 | 保护规则 |
|------|------|----------|
| main | 生产代码 | 必须 PR + 2 Review + CI 通过 |
| develop | 开发集成分支 | 必须 PR + 1 Review + CI 通过 |
| feature/* | 功能分支 | CI 推荐通过 |
| hotfix/* | 热修复分支 | 必须 PR + CI 通过 |

---

## 6. 发布流程

### 6.1 版本号规范

遵循语义化版本 `MAJOR.MINOR.PATCH`：
- **MAJOR**：破坏性更新
- **MINOR**：新增功能（向后兼容）
- **PATCH**：Bug 修复

### 6.2 发布节奏

| 渠道 | 频率 | 说明 |
|------|------|------|
| TestFlight | 按需 | 每次 main 合并后可选自动发布 |
| Google Play Internal | 按需 | 内部测试，快速验证 |
| Google Play Beta | 每 2-4 周 | 外部测试用户 |
| Google Play Production | 每 4-8 周 | 正式发布 |

### 6.3 发布检查清单

- [ ] 所有 CI 检查通过
- [ ] 测试用例覆盖率 ≥ 70%
- [ ] 更新 CHANGELOG.md
- [ ] 更新 versionName / versionCode
- [ ] 通知相关人员
- [ ] 监控发布后 24h 崩溃率

---

## 7. 密钥管理

| 密钥 | 存储位置 | 说明 |
|------|----------|------|
| Android Keystore | GitHub Secrets (base64) | 用于签名 APK/AAB |
| iOS Certificate (.p12) | GitHub Secrets (base64) | 用于代码签名 |
| iOS Provisioning Profile | GitHub Secrets | 用于分发 |
| Firebase credentials | GitHub Secrets | 用于 Crashlytics |

---

## 8. 监控与告警（待补充）

- [ ] Firebase Crashlytics 集成
- [ ] Firebase Performance 监控
- [ ] 崩溃率告警阈值配置
- [ ] 构建失败通知（Slack / Email）

---

_本文档待补充更多细节_
