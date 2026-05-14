# fyrial - 开发指南

## 📋 目录

- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [代码生成](#代码生成)
- [运行应用](#运行应用)
- [构建发布](#构建发布)
- [常见问题](#常见问题)

---

## 🔧 环境要求

### 必需软件

| 软件 | 版本要求 | 下载地址 |
|------|---------|---------|
| **Flutter SDK** | >= 3.11.5 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Dart SDK** | >= 3.11.5 | 随 Flutter 一起安装 |
| **Android Studio** | 最新版 | [developer.android.com](https://developer.android.com/studio) |
| **JDK** | 17+ | [oracle.com](https://www.oracle.com/java/technologies/downloads/) |

### 可选工具

- **VS Code** + Flutter 插件（轻量级替代方案）
- **Git**：版本控制

### 验证安装

```bash
# 检查 Flutter 安装
flutter doctor

# 检查 Dart 版本
dart --version

# 查看可用设备
flutter devices
```

---

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/fomalhaut-m/fyrial.git
cd fyrial
```

### 2. 安装依赖

```bash
cd app
flutter pub get
```

### 3. 连接测试设备

#### Android 设备
1. 开启开发者模式和 USB 调试
2. 通过 USB 连接电脑
3. 授权 USB 调试权限

```bash
# 确认设备已连接
flutter devices
```

#### iOS 设备（需要 macOS）
1. 安装 Xcode
2. 配置开发者账号
3. 信任电脑

---

## 🔨 代码生成

本项目使用 `json_serializable` 自动生成 JSON 序列化代码。

### 方式一：一次性生成（推荐首次使用）

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

### 方式二：监听模式（开发时推荐）

```bash
cd app
dart run build_runner watch --delete-conflicting-outputs
```

保持终端打开，修改模型文件后会自动重新生成。

### 方式三：使用脚本（Windows）

双击项目根目录的 `watch.bat` 文件。

---

## ▶️ 运行应用

### Android

```bash
# 默认设备
flutter run

# 指定设备
flutter run -d <device_id>

# 释放模式（性能更好）
flutter run --release
```

### iOS（macOS only）

```bash
flutter run -d ios
```

### Web

```bash
flutter run -d chrome
```

### 常用运行参数

```bash
# 热重载（保存文件自动刷新）
# 按 r 键

# 热重启（保留状态）
# 按 R 键

# 查看日志
flutter run -v

# 指定端口
flutter run -d android --device-port 5555
```

---

## 📦 构建发布

### Android APK

```bash
# Debug APK（用于测试）
flutter build apk --debug

# Release APK（正式发布）
flutter build apk --release

# 拆分 ABI（减小体积）
flutter build apk --split-per-abi

# 输出位置
# build/app/outputs/flutter-apk/
```

### Android App Bundle（Google Play）

```bash
flutter build appbundle --release
```

### iOS

```bash
# 需要 macOS + Xcode
flutter build ios --release

# 归档到 Xcode
open ios/Runner.xcworkspace
```

### Web

```bash
flutter build web --release
```

### Windows

```bash
flutter build windows --release
```

---

## ❓ 常见问题

### 1. Gradle 下载失败

**错误**：`FileNotFoundException: gradle-8.14-all.zip`

**解决**：已配置阿里云镜像，如仍失败请检查网络。

### 2. 找不到 .g.dart 文件

**错误**：`Error when reading 'song_model.g.dart'`

**解决**：
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

### 3. 设备未识别

**Android**：
```bash
# 重启 ADB
adb kill-server
adb start-server

# 重新连接设备
flutter devices
```

**iOS**：
```bash
# 信任证书
sudo xcodebuild -runFirstLaunch
```

### 4. 依赖冲突

```bash
cd app
flutter clean
flutter pub get
```

### 5. 编译缓慢

- 使用 SSD 硬盘
- 关闭不必要的 IDE 插件
- 增加 Gradle 内存（`gradle.properties`）

---

## 🛠️ 开发工具配置

### VS Code 推荐插件

- Flutter
- Dart
- Pubspec Assist

### Android Studio 推荐插件

- Flutter
- Dart
- File Watcher（自动代码生成）

### IDEA File Watcher 配置

详细配置请参考：[JSON序列化自动配置指南](docs/04-开发阶段/JSON序列化自动配置指南.md)

---

## 📝 开发提示

### 热重载 vs 热重启

| 特性 | 热重载 (r) | 热重启 (R) |
|------|-----------|-----------|
| 速度 | 快 | 较慢 |
| 状态保留 | ✅ | ✅ |
| 适用场景 | UI 修改 | 逻辑修改 |

### 调试技巧

```bash
# 查看详细日志
flutter run -v

# 仅显示错误
flutter run 2>&1 | grep "ERROR"

# 性能分析
flutter run --profile
```

### 清理缓存

```bash
# Flutter 清理
flutter clean

# Gradle 清理
cd android
./gradlew clean

# 重新获取依赖
flutter pub get
```

---

## 📚 相关文档

- [JSON 序列化配置指南](docs/04-开发阶段/JSON序列化自动配置指南.md)
- [常用命令速查](COMMANDS.md)
- [架构设计文档](docs/03-架构设计/)

---

_最后更新：2026-05-14_
