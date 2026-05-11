import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'tables.dart';

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
    // 获取应用文档目录
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'vexfy.db');

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

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}