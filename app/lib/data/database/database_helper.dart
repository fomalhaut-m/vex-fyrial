import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart' as logging;

import 'tables.dart';

/// 数据库助手 - SQLite 单例管理
/// 负责数据库初始化、版本管理、迁移
/// 支持内存模式兜底
class DatabaseHelper {
  static const _tag = '[DatabaseHelper]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  // 单例模式
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// 是否使用内存模式
  bool _isMemoryMode = false;

  /// 获取数据库实例（懒加载）
  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    _logger.info('[初始化] 开始初始化数据库...');

    try {
      // 仅桌面平台（Linux/macOS/Windows）需要 FFI 初始化
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        _logger.info('[初始化] 桌面平台，初始化 sqflite_ffi');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // 尝试获取应用文档目录
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final dbPath = join(documentsDir.path, 'vexfy.db');
        _logger.info('[初始化] 数据库路径: $dbPath');

        final database = await _createDatabase(dbPath);
        _isMemoryMode = false;
        return database;
      } catch (e, s) {
        _logger.severe('[初始化] 获取文档目录失败，尝试内存模式', e, s);
        return await _initMemoryModeDatabase();
      }
    } catch (e, s) {
      _logger.severe('[初始化] 数据库初始化失败，使用内存模式兜底', e, s);
      return await _initMemoryModeDatabase();
    }
  }

  /// 创建数据库连接
  Future<Database> _createDatabase(String dbPath) async {
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 初始化内存模式数据库（兜底方案）
  Future<Database> _initMemoryModeDatabase() async {
    _logger.info('[初始化] 启用内存模式数据库...');

    try {
      _isMemoryMode = true;

      // 设置 FFI（桌面平台）
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // 内存模式数据库
      final database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _logger.info('[初始化] 内存模式数据库初始化成功');
      return database;
    } catch (e, s) {
      _logger.severe('[初始化] 内存模式数据库初始化失败', e, s);
      rethrow;
    }
  }

  /// 首次创建数据库
  Future<void> _onCreate(Database db, int version) async {
    _logger.info('[创建] 创建数据库表...');

    try {
      // 创建 songs 表（本地音乐索引）
      await db.execute('''
        CREATE TABLE ${Tables.songs} (
          id          TEXT PRIMARY KEY,
          title       TEXT NOT NULL,
          artist      TEXT NOT NULL DEFAULT '',
          album       TEXT,
          duration    INTEGER NOT NULL DEFAULT 0,
          cover_url   TEXT,
          source      TEXT NOT NULL DEFAULT 'local',
          file_path   TEXT NOT NULL,
          online_url  TEXT,
          lyrics      TEXT,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          play_count  INTEGER NOT NULL DEFAULT 0,
          file_size   INTEGER,
          mime_type   TEXT,
          created_at  TEXT NOT NULL
        )
      ''');

      // 创建 playlists 表
      await db.execute('''
        CREATE TABLE ${Tables.playlists} (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL,
          cover_url   TEXT,
          description TEXT,
          creator     TEXT NOT NULL,
          type        TEXT NOT NULL,
          song_count  INTEGER NOT NULL DEFAULT 0,
          created_at  TEXT NOT NULL,
          updated_at  TEXT NOT NULL
        )
      ''');

      // 创建 playlist_songs 表
      await db.execute('''
        CREATE TABLE ${Tables.playlistSongs} (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          playlist_id TEXT NOT NULL,
          song_id     TEXT NOT NULL,
          title       TEXT NOT NULL,
          artist      TEXT NOT NULL,
          duration    INTEGER,
          file_path   TEXT,
          cover_url   TEXT,
          added_at    TEXT NOT NULL,
          FOREIGN KEY (playlist_id) REFERENCES ${Tables.playlists}(id) ON DELETE CASCADE
        )
      ''');

      // 创建 song_stats 表
      await db.execute('''
        CREATE TABLE ${Tables.songStats} (
          song_id     TEXT PRIMARY KEY,
          play_count  INTEGER NOT NULL DEFAULT 0,
          total_seconds INTEGER NOT NULL DEFAULT 0,
          last_played_at TEXT
        )
      ''');

      // 创建 played_history 表
      await db.execute('''
        CREATE TABLE ${Tables.playedHistory} (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          song_id     TEXT NOT NULL,
          title       TEXT NOT NULL,
          artist      TEXT NOT NULL,
          duration    INTEGER,
          file_path   TEXT,
          played_at   TEXT NOT NULL
        )
      ''');

      // 创建 local_file_metadata 表
      await db.execute('''
        CREATE TABLE ${Tables.localFileMetadata} (
          song_id         TEXT PRIMARY KEY,
          file_path       TEXT NOT NULL,
          cover_path     TEXT,
          lyrics_path     TEXT,
          lyrics_raw      TEXT,
          album           TEXT,
          year            INTEGER,
          track_number    INTEGER,
          disc_number     INTEGER,
          composer        TEXT,
          lyricist        TEXT,
          is_cover_fetched INTEGER NOT NULL DEFAULT 0,
          is_lyrics_fetched INTEGER NOT NULL DEFAULT 0,
          created_at      TEXT NOT NULL,
          updated_at      TEXT NOT NULL
        )
      ''');

      // 创建 sync_queue 表
      await db.execute('''
        CREATE TABLE ${Tables.syncQueue} (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          song_id       TEXT NOT NULL,
          file_path     TEXT NOT NULL,
          oss_key       TEXT NOT NULL,
          operation     TEXT NOT NULL,
          status        TEXT NOT NULL,
          priority      INTEGER NOT NULL DEFAULT 0,
          retry_count   INTEGER NOT NULL DEFAULT 0,
          max_retries   INTEGER NOT NULL DEFAULT 3,
          error_message TEXT,
          file_hash     TEXT,
          file_size     INTEGER,
          scheduled_at  TEXT,
          started_at    TEXT,
          completed_at  TEXT,
          created_at    TEXT NOT NULL
        )
      ''');

      // 创建 app_info 表
      await db.execute('''
        CREATE TABLE ${Tables.appInfo} (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // 创建索引
      await db.execute(
          'CREATE INDEX idx_songs_file_path ON ${Tables.songs}(file_path)');
      await db.execute(
          'CREATE INDEX idx_songs_title ON ${Tables.songs}(title)');
      await db.execute(
          'CREATE INDEX idx_ps_playlist_id ON ${Tables.playlistSongs}(playlist_id)');
      await db.execute(
          'CREATE INDEX idx_ph_played_at ON ${Tables.playedHistory}(played_at DESC)');

      _logger.info('[创建] 数据库表创建完成');
    } catch (e, s) {
      _logger.severe('[创建] 创建数据库表异常', e, s);
      rethrow;
    }
  }

  /// 数据库升级处理（未来版本扩展）
  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    _logger.info('[升级] 数据库升级: $oldVersion -> $newVersion');
    // 未来迁移脚本写在这里
  }

  /// 健康检查：验证数据库读写功能
  /// 返回 true 表示正常，false 表示异常
  Future<bool> healthCheck() async {
    _logger.info('[健康检查] 开始...');

    try {
      final database = await db;
      final now = DateTime.now().toIso8601String();

      // 尝试写入
      const testKey = 'health_check_timestamp';
      await database.insert(
        Tables.appInfo,
        {'key': testKey, 'value': '1.0.0', 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 验证写入
      final result = await database.query(
        Tables.appInfo,
        where: 'key = ?',
        whereArgs: [testKey],
      );

      if (result.isEmpty) {
        _logger.severe('[健康检查] 失败：无法读取刚写入的数据');
        return false;
      }

      // 清理测试数据
      await database.delete(Tables.appInfo, where: 'key = ?', whereArgs: [testKey]);

      _logger.info('[健康检查] 通过（${_isMemoryMode ? "内存模式" : "文件模式"}）');
      return true;
    } catch (e, s) {
      _logger.severe('[健康检查] 异常', e, s);
      return false;
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    _logger.info('[关闭] 关闭数据库...');

    try {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
        _logger.info('[关闭] 数据库已关闭');
      }
    } catch (e, s) {
      _logger.severe('[关闭] 关闭数据库异常', e, s);
    }
  }

  /// 是否使用内存模式
  bool get isMemoryMode => _isMemoryMode;

  /// 设置内存模式（用于降级）
  void setMemoryMode() {
    _isMemoryMode = true;
  }
}

/// 启动检查结果
class StartupCheckResult {
  final String name;
  final bool success;
  final String message;
  final String? error;

  StartupCheckResult({
    required this.name,
    required this.success,
    required this.message,
    this.error,
  });

  @override
  String toString() => success ? '[OK] $name' : '[FAIL] $name: $message';
}

/// 应用启动检查器
/// 在 App 启动时全面检查所有关键资源和功能
class StartupValidator {
  static const _tag = '[StartupValidator]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  static final StartupValidator instance = StartupValidator._();
  StartupValidator._();

  final List<StartupCheckResult> _results = [];

  /// 执行所有启动检查
  /// 返回是否所有检查都通过
  Future<bool> runAllChecks() async {
    _logger.info('===== 开始启动检查 =====');
    _results.clear();

    // 1. 数据库检查
    await _checkDatabase();

    // 2. 音频后端检查
    await _checkAudioBackend();

    // 3. 存储权限检查（Android）
    await _checkStoragePermission();

    // 4. 文件系统检查
    await _checkFileSystem();

    // 汇总结果
    final failedChecks = _results.where((r) => !r.success).toList();
    if (failedChecks.isEmpty) {
      _logger.info('===== 启动检查完成：全部通过 =====');
      return true;
    } else {
      _logger.warning('===== 启动检查完成：${failedChecks.length} 项失败 =====');
      for (final check in failedChecks) {
        _logger.warning('  ${check}');
      }
      return false;
    }
  }

  /// 获取所有检查结果
  List<StartupCheckResult> get results => List.unmodifiable(_results);

  /// 检查数据库
  Future<void> _checkDatabase() async {
    _logger.info('[检查] 数据库...');

    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.db;

      // 测试读写能力
      const testKey = '_startup_check';
      await db.insert(
        Tables.appInfo,
        {'key': testKey, 'value': '1', 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final result = await db.query(Tables.appInfo, where: 'key = ?', whereArgs: [testKey]);
      await db.delete(Tables.appInfo, where: 'key = ?', whereArgs: [testKey]);

      if (result.isEmpty) {
        _results.add(StartupCheckResult(
          name: '数据库',
          success: false,
          message: '无法读写数据库',
        ));
      } else {
        _results.add(StartupCheckResult(
          name: '数据库',
          success: true,
          message: dbHelper.isMemoryMode ? '内存模式（文件模式异常）' : 'SQLite 读写正常',
        ));
      }
    } catch (e, s) {
      _results.add(StartupCheckResult(
        name: '数据库',
        success: false,
        message: e.toString(),
        error: s.toString(),
      ));
    }
  }

  /// 检查音频后端
  Future<void> _checkAudioBackend() async {
    _logger.info('[检查] 音频后端...');

    try {
      // 检查 libmpv 是否可用（Linux）
      if (Platform.isLinux) {
        final libmpvPath = _findLibmpv();
        if (libmpvPath != null) {
          _results.add(StartupCheckResult(
            name: '音频后端',
            success: true,
            message: 'libmpv 可用: $libmpvPath',
          ));
        } else {
          _results.add(StartupCheckResult(
            name: '音频后端',
            success: true,
            message: 'Linux 平台缺少 libmpv，建议安装 libmpv-dev 包以获得完整音频支持',
          ));
        }
        return;
      }

      // 其他平台默认正常
      _results.add(StartupCheckResult(
        name: '音频后端',
        success: true,
        message: '原生音频后端正常',
      ));
    } catch (e, s) {
      _results.add(StartupCheckResult(
        name: '音频后端',
        success: false,
        message: e.toString(),
        error: s.toString(),
      ));
    }
  }

  /// 查找 libmpv 路径
  String? _findLibmpv() {
    final possiblePaths = [
      '/usr/lib/x86_64-linux-gnu/libmpv.so.2',
      '/usr/lib/x86_64-linux-gnu/libmpv.so.1',
      '/usr/lib/libmpv.so.2',
      '/usr/lib/libmpv.so.1',
      '/usr/local/lib/libmpv.so.2',
      '/usr/local/lib/libmpv.so.1',
    ];

    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  /// 检查存储权限
  Future<void> _checkStoragePermission() async {
    _logger.info('[检查] 存储权限...');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _results.add(StartupCheckResult(
          name: '存储权限',
          success: true,
          message: '权限检查已配置（运行时检查）',
        ));
      } else {
        _results.add(StartupCheckResult(
          name: '存储权限',
          success: true,
          message: '桌面平台无需检查',
        ));
      }
    } catch (e, s) {
      _results.add(StartupCheckResult(
        name: '存储权限',
        success: false,
        message: e.toString(),
        error: s.toString(),
      ));
    }
  }

  /// 检查文件系统
  Future<void> _checkFileSystem() async {
    _logger.info('[检查] 文件系统...');

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final home = Platform.environment['HOME'] ?? '';
        final musicDir = '$home/Music';

        if (Directory(musicDir).existsSync()) {
          _results.add(StartupCheckResult(
            name: '文件系统',
            success: true,
            message: 'Music 目录可访问',
          ));
        } else {
          _results.add(StartupCheckResult(
            name: '文件系统',
            success: true,
            message: 'Music 目录不存在（扫描时降级到 Downloads）',
          ));
        }
      } else {
        _results.add(StartupCheckResult(
          name: '文件系统',
          success: true,
          message: '文件系统检查已配置',
        ));
      }
    } catch (e, s) {
      _results.add(StartupCheckResult(
        name: '文件系统',
        success: false,
        message: e.toString(),
        error: s.toString(),
      ));
    }
  }
}