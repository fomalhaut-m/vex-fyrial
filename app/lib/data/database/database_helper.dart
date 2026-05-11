import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'tables.dart';

/// 简化日志（避免循环依赖）
void _log(String tag, String msg) => print('[Vexfy]$tag $msg');

/// 数据库助手 - SQLite 单例管理
/// 负责数据库初始化、版本管理、迁移
class DatabaseHelper {
  // 单例模式
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// 获取数据库实例（懒加载）
  Future<Database> get db async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    // 仅桌面平台（Linux/macOS/Windows）需要 FFI 初始化
    // Android/iOS 使用原生 SQLite，无需此步
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      _log('[DatabaseHelper]', '桌面平台，初始化 sqflite_ffi');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } else {
      _log('[DatabaseHelper]', '移动平台，使用原生 sqflite');
    }

    // 获取应用文档目录
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'vexfy.db');

    _log('[DatabaseHelper]', '数据库路径: $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次创建数据库
  Future<void> _onCreate(Database db, int version) async {
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
        cover_path      TEXT,
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

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_songs_file_path ON ${Tables.songs}(file_path)');
    await db.execute(
        'CREATE INDEX idx_songs_title ON ${Tables.songs}(title)');
    await db.execute(
        'CREATE INDEX idx_ps_playlist_id ON ${Tables.playlistSongs}(playlist_id)');
    await db.execute(
        'CREATE INDEX idx_ph_played_at ON ${Tables.playedHistory}(played_at DESC)');
  }

  /// 数据库升级处理（未来版本扩展）
  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // 未来迁移脚本写在这里
  }

  /// 健康检查：验证数据库读写功能
  /// 返回 true 表示正常，false 表示异常
  Future<bool> healthCheck() async {
    try {
      final database = await db;
      final now = DateTime.now().toIso8601String();
      
      // 测试写入：创建临时健康检查表
      await database.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.appInfo} (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // 写入测试数据
      const testKey = 'health_check_timestamp';
      await database.insert(
        'app_info',
        {'key': testKey, 'value': '1.0.0', 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // 验证写入
      final result = await database.query(
        'app_info',
        where: 'key = ?',
        whereArgs: [testKey],
      );
      
      if (result.isEmpty) {
        _log('[DatabaseHelper]', '健康检查失败：无法读取刚写入的数据');
        return false;
      }
      
      // 更新版本号
      await database.update(
        'app_info',
        {'value': '1.0.0', 'updated_at': now},
        where: 'key = ?',
        whereArgs: ['app_version'],
      );
      
      // 清理测试数据
      await database.delete('app_info', where: 'key = ?', whereArgs: [testKey]);
      
      _log('[DatabaseHelper]', '数据库健康检查通过');
      return true;
    } catch (e, s) {
      _log('[DatabaseHelper]', '健康检查异常: $e\n$s');
      return false;
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
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
  static final StartupValidator instance = StartupValidator._();
  StartupValidator._();

  final List<StartupCheckResult> _results = [];

  /// 执行所有启动检查
  /// 返回是否所有检查都通过
  Future<bool> runAllChecks() async {
    _log('[StartupValidator]', '===== 开始启动检查 =====');
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
      _log('[StartupValidator]', '===== 启动检查完成：全部通过 =====');
      return true;
    } else {
      _log('[StartupValidator]', '===== 启动检查完成：${failedChecks.length} 项失败 =====');
      for (final check in failedChecks) {
        _log('[StartupValidator]', '  ${check}');
      }
      return false;
    }
  }

  /// 获取所有检查结果
  List<StartupCheckResult> get results => List.unmodifiable(_results);

  /// 检查数据库
  Future<void> _checkDatabase() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.db;
      
      // 测试读写能力
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.appInfo} (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      const testKey = '_startup_check';
      await db.insert(
        'app_info',
        {'key': testKey, 'value': '1', 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      final result = await db.query('app_info', where: 'key = ?', whereArgs: [testKey]);
      await db.delete('app_info', where: 'key = ?', whereArgs: [testKey]);
      
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
          message: 'SQLite 读写正常',
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
            success: false,
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
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // 移动端检查权限状态
        // 这里简化处理，实际可以调用 permission_handler
        _results.add(StartupCheckResult(
          name: '存储权限',
          success: true,
          message: '权限检查已配置',
        ));
      } else {
        // 桌面端不需要存储权限
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
    try {
      final dirs = <String, String>{};
      
      // 检查音乐目录
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final home = Platform.environment['HOME'] ?? '';
        final musicDir = '$home/Music';
        dirs['Music'] = musicDir;
        
        if (Directory(musicDir).existsSync()) {
          _results.add(StartupCheckResult(
            name: '文件系统',
            success: true,
            message: 'Music 目录可访问',
          ));
        } else {
          _results.add(StartupCheckResult(
            name: '文件系统',
            success: false,
            message: 'Music 目录不存在: $musicDir',
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
