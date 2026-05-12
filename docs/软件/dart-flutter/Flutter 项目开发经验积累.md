# Flutter 项目开发经验积累

> **核心理念：技术经验要积累不要遗忘。每一次踩坑、每一个新方案，都必须记录到知识库。**

本文档记录 Vexfy 项目开发过程中积累的实战经验，供团队成员参考和复用。

---

## 一、架构设计经验

### 1.1 核心原则清单

| 原则 | 说明 | 状态 |
|------|------|------|
| 日志打印 | 所有关键步骤都有日志 | ✅ 已落地 |
| 异常处理 | 每个 async 函数都要 try-catch | ✅ 已落地 |
| 异常兜底 | 功能失败 App 不能崩 | ✅ 已落地 |
| 健康检测 | 启动时检测各项功能可用性 | ✅ 已落地 |
| 经验积累 | 发现问题/新方案必须记录 | ✅ 已落地 |

### 1.2 健康检测机制（可复用模板）

**理念：** 启动时全面检测各项功能是否可用，通过日志精确暴露问题，任何功能失败不影响 App 启动。

**适用场景：** 音乐播放器、文件管理器、网络应用等依赖多个底层功能的应用。

**模板代码：**

```dart
/// 健康检测结果
class HealthCheckResult {
  final String feature;
  final bool isHealthy;
  final String message;
  final String? error;

  const HealthCheckResult({
    required this.feature,
    required this.isHealthy,
    required this.message,
    this.error,
  });
}

/// 健康检测服务
class HealthCheckService {
  static final HealthCheckService instance = HealthCheckService._();
  HealthCheckService._();

  final List<HealthCheckResult> _results = [];

  Future<bool> runAllChecks() async {
    _results.clear();

    // 每个检测项独立 try-catch，失败不影响整体
    await _checkDatabase();
    await _checkFileSystem();
    await _checkPermissions();
    await _checkNetwork();
    await _checkAudioPlayback();

    return _results.every((r) => r.isHealthy);
  }

  Future<void> _checkDatabase() async {
    try {
      // 检测逻辑
      _results.add(HealthCheckResult(
        feature: '数据库',
        isHealthy: true,
        message: '正常',
      ));
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '数据库',
        isHealthy: false,
        message: '异常：$e',
        error: s.toString(),
      ));
    }
  }

  // ... 其他检测项类似
}
```

**日志输出规范：**
```
[健康检测] 数据库: 正常
[健康检测] 文件读写: 正常
[健康检测] 存储权限: 正常
[健康检测] 网络: 离线（本地功能正常）
[健康检测] 音频播放: 正常
```

---

## 二、异常处理模式

### 2.1 标准 async 函数模板

```dart
Future<void> someAsyncMethod(dynamic arg) async {
  // 1. 打印入参
  talker.info('[模块] someAsyncMethod() 入参: arg=$arg');

  try {
    // 2. 业务逻辑（每步都可加 debug 日志）
    talker.fine('[模块] 正在执行 XXX');
    await _doSomething();
    talker.info('[模块] 执行成功');

  } catch (e, s) {
    // 3. 记录异常日志
    talker.severe('[模块] someAsyncMethod 异常', exception: e, stackTrace: s);

    // 4. 设置错误状态（让 UI 层知道出错了）
    state = state.copyWith(error: '操作失败: $e');

    // 5. 安全返回（不 rethrow，除非顶层需要处理）
  }
}
```

### 2.2 异常兜底策略表

| 场景 | 兜底方案 | 代码示例 |
|------|----------|----------|
| 播放器初始化失败 | 设置 error，UI 显示提示 | `state = state.copyWith(error: '播放器暂不可用')` |
| 数据库初始化失败 | 降级到内存模式 | `openDatabase(inMemoryDatabasePath)` |
| 音频服务启动失败 | 继续运行，不阻断主流程 | `catch` 内仅打印日志，不抛出 |
| 文件不存在 | 显示友好提示 | `state = state.copyWith(error: '文件不存在')` |
| 权限获取失败 | 提示用户手动选择 | 降级到 file_picker 让用户选择目录 |

### 2.3 全局异常兜底（main.dart 模板）

```dart
Future<void> main() async {
  try {
    // 初始化数据库（失败降级到内存模式）
    await _initDatabaseWithFallback();

    // 健康检测（失败不影响 App 启动）
    await HealthCheckService.instance.runAllChecks();

    // 启动音频服务（失败不影响主功能）
    try {
      await startAudioService();
    } catch (e) {
      talker.warning('[main] 音频服务启动失败（继续运行）', exception: e);
    }

    runApp(ProviderScope(child: VexfyApp()));
  } catch (e, s) {
    // 显示错误界面，不闪退
    runApp(_ErrorApp(message: '启动异常: $e'));
  }
}
```

---

## 三、依赖替换经验

### 3.1 GetX → Riverpod 迁移

**原依赖：** `get: ^4.6.6`

**替换为：** `flutter_riverpod: ^2.5.0`

**迁移要点：**

| GetX 概念 | Riverpod 等价 | 说明 |
|-----------|---------------|------|
| `Get.put(xxx, permanent: true)` | `Get.put(PlayerNotifier())` | 需要在 `runApp` 之前注册 |
| `Obx(() => ...)` | `ConsumerWidget` + `ref.watch()` | 响应式 UI |
| `Get.find<Service>()` | `ref.read(provider)` | 获取服务实例 |
| `Get.toNamed('/xxx')` | `context.go('/xxx')` | 路由跳转 |

**注意：** GetX 的路由和 GetMaterialApp 需要完全替换为 go_router。

### 3.2 on_audio_query_pluse → permission_handler + file_picker

**原依赖：** `on_audio_query_pluse: ^3.0.6`

**替换为：**
- `permission_handler: ^11.3.1`
- `file_picker: ^8.3.0`

**迁移原因：** `on_audio_query_pluse` 在桌面平台支持有限，改用原生权限 API + 文件选择器更可靠。

**迁移代码示例：**

```dart
// 权限请求
final status = await Permission.storage.request();
if (status.isGranted) {
  // 有权限，正常扫描
} else if (status.isPermanentlyDenied) {
  // 权限被拒绝，让用户手动选择目录
  final dir = await FilePicker.platform.getDirectoryPath();
}

// 自定义目录扫描
await for (final entity in directory.list(recursive: true)) {
  if (entity is File && _isSupportedFormat(entity.path)) {
    // 处理音频文件
  }
}
```

### 3.3 logging + print → talker

**原依赖：** `logging: ^1.3.0`

**替换为：** `talker: ^4.5.0` + `talker_flutter: ^4.5.0`

**优势：**
- 统一日志级别（info/debug/warning/severe）
- 支持异常和堆栈的 structured logging
- 内置 Flutter 监控页面 `TalkerWrapper`
- 日志历史记录（maxHistory）

**注意：** talker 的日志输出需要在 `main()` 最开始初始化。

---

## 四、Linux 桌面开发经验

### 4.1 必装依赖

| 依赖 | 安装命令 | 说明 |
|------|---------|------|
| libmpv-dev | `sudo apt install libmpv-dev` | just_audio_mpv 后端 |
| sqflite_ffi | 自动引入 | 桌面 SQLite 支持 |
| GTK/Flutter 桌面工具链 | 见 Flutter 官方文档 | 编译桌面应用 |

**验证命令：**
```bash
# 检查 libmpv 是否可用
ldconfig -p | grep libmpv

# 检查 Flutter 桌面支持
flutter doctor
```

### 4.2 平台判断代码模板

```dart
import 'dart:io';

void platformSpecificLogic() {
  if (Platform.isLinux) {
    // Linux 特定逻辑
    final libmpvPath = _findLibmpv();
  } else if (Platform.isAndroid) {
    // Android 特定逻辑
    final status = await Permission.audio.request();
  } else if (Platform.isWindows) {
    // Windows 特定逻辑
  } else if (Platform.isMacOS) {
    // macOS 特定逻辑
  }
}
```

### 4.3 常见踩坑

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 音频播放没声音 | Linux 缺少 libmpv | 安装 libmpv-dev |
| 数据库初始化失败 | 文档目录不可写 | 降级到内存模式 |
| 文件扫描不到文件 | 目录不存在 | 降级到 Downloads 目录 |
| Flutter 桌面编译失败 | 未启用桌面支持 | `flutter config --enable-linux-desktop` |

---

## 五、日志系统经验

### 5.1 talker 配置模板

```dart
// main.dart 顶部
final talker = Talker(
  settings: TalkerSettings(
    maxHistory: 2000,
    enabled: true,
    consoleEnabled: true,
  ),
);

// main() 最开始
void main() async {
  _setupExceptionHandlers();
  talker.info('[main] App 启动');
  // ...
}

// 全局异常处理
void _setupExceptionHandlers() {
  FlutterError.onError = (details) {
    talker.severe('[FlutterError] Widget 异常',
        exception: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    talker.severe('[Platform] 平台异常', exception: error, stackTrace: stack);
    return true;
  };
}
```

### 5.2 日志级别选用指南

| 级别 | 使用场景 | 示例 |
|------|---------|------|
| `info` | 流程开始/结束、重要里程碑 | `[main] App 启动`、`[扫描] 完成，共 100 首` |
| `debug` / `fine` | 详细调试信息 | `[控制] togglePlayPause()`、`[播放] 加载文件` |
| `warning` | 异常但可恢复 | `[权限] 权限被拒绝，降级到手动选择` |
| `severe` | 严重错误，需要关注 | `[初始化] 播放器初始化失败`、`[数据库] 健康检查失败` |

### 5.3 异常日志规范

```dart
// ✅ 正确
talker.severe('[模块] 方法名 异常',
    exception: e,
    stackTrace: s);

// ✅ 带额外信息
talker.warning('[权限] audio 权限被拒绝（可再次请求）');

// ❌ 错误
print('error: $e');           // 无日志级别
log('something happened');    // 无上下文
```

---

## 六、知识库维护规范

### 6.1 记录时机（强制）

| 时机 | 记录内容 | 存放位置 |
|------|----------|----------|
| 发现新问题 | 问题现象、原因、解决方案 | 本文档「踩坑记录」章节 |
| 新技术方案落地 | 方案背景、核心代码、注意事项 | 本文档对应章节 |
| 依赖替换 | 替换原因、迁移步骤、避坑点 | 本文档「依赖替换经验」章节 |
| Linux 踩坑 | 问题、原因、解决方案 | 本文档「Linux 开发经验」章节 |
| 架构设计决策 | 决策背景、备选方案、最终选择 | 本文档「架构设计经验」章节 |

### 6.2 记录格式

```markdown
### 问题标题
**日期：** YYYY-MM-DD
**模块：** 所属功能模块
**问题描述：**
> 详细描述问题现象

**原因分析：**
> 分析根本原因

**解决方案：**
> 具体解决方案和代码

**经验总结：**
> 可复用的经验教训
```

### 6.3 知识库路径

```
docs/
└── 软件/
    └── dart-flutter/
        └── Flutter 项目开发经验积累.md   # 本文档
```

---

## 七、踩坑记录

### 7.1 just_audio 在 Linux 无声音

**日期：** 2026-05
**模块：** 音频播放

**问题描述：**
在 Linux 桌面平台，`just_audio` 播放音频没有声音，但没有任何报错。

**原因分析：**
`just_audio` 在 Linux 平台需要 `just_audio_mpv` 作为音频后端，而系统未安装 `libmpv`。

**解决方案：**
1. 安装 `libmpv-dev`：`sudo apt install libmpv-dev`
2. 在 `pubspec.yaml` 添加 `just_audio_mpv: ^0.1.7`
3. 添加平台判断，提示用户安装依赖

**经验总结：**
Linux 桌面开发必须检查 libmpv 是否可用，health check 中要包含音频检测。

### 7.2 GetX 路由与 Riverpod 冲突

**日期：** 2026-05
**模块：** 路由 + 状态管理

**问题描述：**
迁移到 Riverpod 后，页面使用 `Obx` 仍能响应，但 `context.go()` 跳转后状态丢失。

**原因分析：**
`GetMaterialApp` 在内部维护了 GetX 的依赖注入池，迁移到 `MaterialApp.router` 后，原有的 `Get.put` 注册消失。

**解决方案：**
1. 弃用 `GetMaterialApp`，改用 `MaterialApp.router`
2. 所有服务通过 `ProviderScope` 注入
3. 页面改用 `ConsumerWidget`

**经验总结：**
GetX 的路由和依赖注入是强耦合的，必须同时迁移，不能只换状态管理。

### 7.3 数据库内存模式数据丢失

**日期：** 2026-05
**模块：** 数据库

**问题描述：**
数据库初始化失败降级到内存模式后，App 重启数据全部丢失。

**原因分析：**
内存模式数据库 `openDatabase(inMemoryDatabasePath)` 是进程级别的，重启后数据清空。

**解决方案：**
1. 在日志中明确标注内存模式：`[健康检测] 数据库: 正常（内存模式）`
2. 提示用户：`数据库异常，部分功能可能受限`
3. 未来考虑增加数据导出功能

**经验总结：**
内存模式是保命策略，需要在 UI 层明确提示用户数据无法持久化。

### 7.4 permission_handler 权限永久拒绝

**日期：** 2026-05
**模块：** 权限管理

**问题描述：**
用户永久拒绝存储权限后，应用无法再次请求，也无法正常扫描音乐。

**原因分析：**
`permission_handler` 在权限永久拒绝后不会再弹系统对话框，需要用户手动到设置中开启。

**解决方案：**
1. 检测到 `isPermanentlyDenied` 时，不崩溃
2. 降级到让用户手动选择音乐目录（`FilePicker.getDirectoryPath`）
3. 显示友好提示：存储权限被拒绝，请在设置中开启，或选择音乐目录

**经验总结：**
权限相关功能必须有降级方案，不能让用户因为权限问题无法使用 App。

---

## 八、可复用代码模板

### 8.1 带兜底的播放器初始化

```dart
class PlayerNotifier extends Notifier<PlayerState> {
  bool _isInitialized = false;

  @override
  PlayerState build() {
    _initPlayer();
    return const PlayerState();
  }

  Future<void> _initPlayer() async {
    try {
      _player = AudioPlayer();
      // 初始化监听器...
      _isInitialized = true;
      talker.info('[初始化] 播放器初始化成功');
    } catch (e, s) {
      talker.severe('[初始化] 播放器初始化失败', exception: e, stackTrace: s);
      state = state.copyWith(error: '播放器初始化失败，请重启 App');
    }
  }

  Future<void> playSong(SongModel song) async {
    if (!_isInitialized) {
      talker.warning('[播放] 播放器未初始化');
      state = state.copyWith(error: '播放器暂不可用');
      return;
    }
    // 正常播放逻辑...
  }
}
```

### 8.2 带权限兜底的音乐扫描

```dart
Future<int> scanAllMusic() async {
  state = state.copyWith(isScanning: true, error: null);

  try {
    // 请求权限
    final hasPermission = await requestPermission();

    if (!hasPermission) {
      // 降级到用户选择目录
      final dir = await pickMusicDirectory();
      if (dir == null) {
        // 用户取消，返回 0
        state = state.copyWith(isScanning: false);
        return 0;
      }
      return await _scanDirectory(dir);
    }

    return await _scanDefaultDirectories();
  } catch (e, s) {
    talker.severe('[扫描] scanAllMusic 异常', exception: e, stackTrace: s);
    state = state.copyWith(isScanning: false, error: '扫描失败: $e');
    return 0;
  }
}
```

### 8.3 降级到内存模式的数据库

```dart
Future<Database> _initDatabase() async {
  try {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'vexfy.db');
    return await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  } catch (e, s) {
    talker.severe('[数据库] 初始化失败，降级到内存模式', exception: e, stackTrace: s);
    return await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
    );
  }
}
```

---

## 九、团队协作规范

### 9.1 新人上手检查清单

- [ ] Flutter SDK 已安装
- [ ] `flutter doctor` 无重大警告
- [ ] Linux 桌面：`sudo apt install libmpv-dev`
- [ ] 理解日志级别规范
- [ ] 理解异常处理原则
- [ ] 理解健康检测机制
- [ ] 知道知识库路径和记录规范

### 9.2 Code Review 关注点

| 检查项 | 说明 |
|--------|------|
| 日志 | 关键步骤是否有日志？异常是否记录？ |
| 异常处理 | async 函数是否都有 try-catch？ |
| 兜底 | 是否有 fallback 逻辑？App 会不会崩？ |
| 知识库 | 新踩坑是否有记录？ |

### 9.3 经验分享节奏

- **每次迭代结束：** 回顾本次踩坑，更新知识库
- **每周五：** 团队经验分享（15 分钟）
- **每次发版：** 检查知识库是否同步更新

---

## 十、版本历史

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-05-12 | v1.0 | 初始版本：架构设计经验、健康检测机制、异常处理模式 |
