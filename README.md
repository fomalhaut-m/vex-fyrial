# Vexfy - 个人音乐播放器

> 流畅、稳定、低内存的本地音乐播放器，专为音乐爱好者打造

## ✨ 功能特性

- 🎵 **本地音乐管理**：自动扫描设备上所有音频文件，支持分类浏览
- 🎧 **高品质播放**：支持多种音频格式，流畅无卡顿
- 🎚️ **完整播放控制**：播放/暂停、上一首/下一首、进度调整、播放模式切换
- 📱 **后台播放**：支持后台播放和通知栏控制，锁屏也能操作
- 📊 **播放统计**：记录听歌时长、播放次数、最爱歌曲等数据
- 📝 **播放列表**：自定义播放列表，自由添加/删除歌曲
- 🎨 **现代UI设计**：简洁美观的界面，流畅的动画效果
- ⚡ **低内存占用**：优化性能，占用内存小，运行流畅
- 🌙 **深色模式**：支持深色/浅色主题切换（开发中）

## 🛠️ 技术栈

- **框架**：Flutter 3.x
- **状态管理**：GetX 4.6.x
- **路由管理**：GetX Router
- **本地数据库**：Sqflite
- **音频播放**：
  - just_audio：核心音频播放
  - audio_service：后台播放和通知栏控制
  - on_audio_query：本地音乐扫描
- **开发语言**：Dart

## 📁 项目结构

```
vexfy/
├── app/                          # 应用主目录
│   ├── lib/
│   │   ├── app/                  # 应用核心
│   │   │   ├── core/             # 核心配置
│   │   │   │   └── theme.dart    # 主题配置
│   │   │   ├── modules/          # 业务模块
│   │   │   │   ├── home/         # 主页（底部Tab容器）
│   │   │   │   ├── player/       # 播放器模块
│   │   │   │   ├── playlist/     # 播放列表模块
│   │   │   │   ├── settings/     # 设置模块
│   │   │   │   └── stats/        # 统计模块
│   │   │   └── routes/           # 路由配置
│   │   ├── data/                 # 数据层
│   │   │   ├── database/         # 数据库相关
│   │   │   └── models/           # 数据模型
│   │   ├── services/             # 服务层（全局单例）
│   │   │   ├── audio_handler_service.dart  # 音频后台服务
│   │   │   ├── local_music_service.dart    # 本地音乐扫描服务
│   │   │   └── player_service.dart         # 播放器核心服务
│   │   ├── widgets/              # 公共组件
│   │   │   └── mini_player.dart  # 迷你播放器
│   │   └── main.dart             # 应用入口
│   ├── android/                  # Android 平台配置
│   ├── ios/                      # iOS 平台配置
│   ├── linux/                    # Linux 平台配置
│   ├── macos/                    # macOS 平台配置
│   ├── web/                      # Web 平台配置
│   ├── windows/                  # Windows 平台配置
│   └── pubspec.yaml              # 项目依赖配置
└── docs/                         # 项目文档
    ├── 01-产品设计/              # 产品设计文档
    ├── 02-UI设计/                # UI设计规范
    ├── 03-架构设计/              # 架构设计文档
    ├── 05-测试阶段/              # 测试相关文档
    └── 06-部署阶段/              # 部署相关文档
```

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.5
- Android Studio / VS Code

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/fomalhaut-m/vexfy.git
   cd vexfy
   ```

2. **安装依赖**
   ```bash
   cd app
   flutter pub get
   ```

3. **运行项目**
   ```bash
   # Android
   flutter run
   
   # iOS (需要 macOS + Xcode)
   flutter run -d ios
   ```

## 📱 构建发布

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## 🤝 开发规范

- 遵循 Flutter 官方开发规范
- 使用 GetX 状态管理，页面逻辑放在 Controller 中
- 服务层使用单例模式，全局统一访问
- 代码提交遵循 Conventional Commits 规范
- 功能开发前请先阅读相关设计文档

## 📄 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件

## 👥 作者

fomalhaut-m

---

### 开发进度

- ✅ 项目初始化和基础框架搭建
- ✅ 本地音乐扫描功能
- ✅ 核心播放器功能
- ✅ 后台播放和通知栏控制
- ✅ 迷你播放器组件
- ✅ 播放列表功能
- ⏳ 播放统计功能（开发中）
- ⏳ 设置页面（开发中）
- ⏳ 深色模式支持（规划中）
- ⏳ 歌词显示（规划中）
- ⏳ 音效均衡器（规划中）
