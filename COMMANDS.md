# fyrial - 开发命令速查

## 📦 依赖管理

```bash
# 获取依赖
cd app && flutter pub get

# 升级依赖
cd app && flutter pub upgrade
```

## 🔨 代码生成

```bash
# 一次性生成代码（Riverpod、Freezed 等）
cd app && dart run build_runner build --delete-conflicting-outputs

# 监听模式（开发时自动重新生成）
cd app && dart run build_runner watch --delete-conflicting-outputs
```

## 🧹 清理

```bash
# 清理构建文件
cd app && flutter clean

# 清理后重新获取依赖
cd app && flutter clean && flutter pub get
```

## 🚀 运行

```bash
# 运行 Android（默认设备）
cd app && flutter run

# 指定设备运行
cd app && flutter devices                    # 查看可用设备
cd app && flutter run -d <device_id>         # 指定设备

# 运行 Web
cd app && flutter run -d chrome

# 运行 iOS（需要 macOS）
cd app && flutter run -d ios
```

## 📱 构建发布

```bash
# Android APK
cd app && flutter build apk --release

# Android App Bundle
cd app && flutter build appbundle --release

# iOS
cd app && flutter build ios --release

# Web
cd app && flutter build web --release
```

## 🧪 测试

```bash
# 运行所有测试
cd app && flutter test

# 运行特定测试文件
cd app && flutter test test/widget_test.dart

# 生成覆盖率报告
cd app && flutter test --coverage
```

## 📝 代码分析

```bash
# 静态分析
cd app && flutter analyze

# 格式化代码
cd app && dart format .

# 检查过时依赖
cd app && flutter pub outdated
```

## 💡 快捷提示

### Windows PowerShell 别名（可选）

在 PowerShell 配置文件（`$PROFILE`）中添加：

```powershell
# 快速切换到 app 目录
function cdapp { Set-Location "C:\work\vex\vex-fyrial\app" }

# 快速构建
function fbuild { dart run build_runner build --delete-conflicting-outputs }

# 快速运行
function frun { flutter run }
```

使用后：
```powershell
cdapp      # 切换到 app 目录
fbuild     # 生成代码
frun       # 运行应用
```

### Linux/Mac Bash 别名（可选）

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
alias cdapp='cd /path/to/fyrial/app'
alias fbuild='dart run build_runner build --delete-conflicting-outputs'
alias fwatch='dart run build_runner watch --delete-conflicting-outputs'
alias frun='flutter run'
```

---

_最后更新: 2026-05-14_
