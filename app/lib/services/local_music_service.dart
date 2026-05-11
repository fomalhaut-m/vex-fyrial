import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:sqflite/sqflite.dart';

import '../data/database/database_helper.dart';
import '../data/database/tables.dart';
import '../data/models/song_model.dart';

/// 本地音乐扫描服务
/// 负责扫描设备上的音频文件，解析元数据，存入 SQLite
/// 支持格式：MP3、AAC、FLAC、WAV、MP4
class LocalMusicService {
  // 单例模式
  LocalMusicService._();
  static final LocalMusicService instance = LocalMusicService._();

  final oaq.OnAudioQuery _audioQuery = oaq.OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 检查权限并请求
  /// 返回 true 表示有权限
  Future<bool> requestPermission() async {
    return await _audioQuery.checkAndRequest();
  }

  /// 全量扫描本地音乐
  /// 递归扫描配置的目录，解析 ID3 标签，存入数据库
  /// 返回扫描到的歌曲数量
  Future<int> scanAllMusic({
    void Function(int scanned, int total)? onProgress,
  }) async {
    // 请求权限
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('缺少存储权限，请到设置中授予权限');
    }

    // 查询所有音频文件
    final songs = await _audioQuery.querySongs(
      sortType: oaq.SongSortType.TITLE,
      orderType: oaq.OrderType.ASC_OR_SMALLER,
      uriType: oaq.UriType.EXTERNAL,
      ignoreCase: true,
    );

    int count = 0;
    final total = songs.length;

    for (final song in songs) {
      // 只处理支持的格式
      final uri = song.data ?? song.uri ?? '';
      if (!_isSupportedFormat(uri)) {
        continue;
      }

      // 构造 SongModel
      final songModel = _fromAudioSongModel(song);

      // 存入数据库（更新或插入）
      await _upsertSong(songModel);
      count++;

      // 回调进度
      onProgress?.call(count, total);
    }

    return count;
  }

  /// 将 on_audio_query 的 SongModel 转为我们的 SongModel
  SongModel _fromAudioSongModel(oaq.SongModel audioSong) {
    // audioSong 字段：id, title, artist, album, duration, data, uri, size, mimeType 等
    final filePath = audioSong.data ?? audioSong.uri ?? '';

    return SongModel(
      id: _generateSongId(filePath),
      title: audioSong.title ?? '未知歌曲',
      artist: audioSong.artist ?? '未知歌手',
      album: audioSong.album,
      duration: audioSong.duration ?? 0,
      coverUrl: null, // 封面需要单独查询
      source: SongSource.local,
      filePath: filePath,
      onlineUrl: null,
      lyrics: null,
      isFavorite: false,
      playCount: 0,
      fileSize: audioSong.size,
      mimeType: audioSong.mimeType,
      createdAt: DateTime.now(),
    );
  }

  /// 生成歌曲唯一 ID（文件路径的 MD5 哈希）
  String _generateSongId(String filePath) {
    final bytes = md5.convert(utf8.encode(filePath));
    return bytes.toString();
  }

  /// 判断是否支持该格式
  bool _isSupportedFormat(String uri) {
    final lower = uri.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.m4a'); // m4a 也是 AAC 格式
  }

  /// 插入或更新歌曲（已存在则更新，不存在则插入）
  Future<void> _upsertSong(SongModel song) async {
    final db = await _dbHelper.db;
    await db.insert(
      Tables.songs,
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从数据库加载所有本地歌曲
  Future<List<SongModel>> loadAllSongs() async {
    final db = await _dbHelper.db;
    final rows = await db.query(
      Tables.songs,
      orderBy: 'title ASC',
    );
    return rows.map((row) => SongModel.fromMap(row)).toList();
  }

  /// 根据 ID 获取歌曲
  Future<SongModel?> getSongById(String id) async {
    final db = await _dbHelper.db;
    final rows = await db.query(
      Tables.songs,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SongModel.fromMap(rows.first);
  }

  /// 根据文件路径获取歌曲
  Future<SongModel?> getSongByPath(String filePath) async {
    final db = await _dbHelper.db;
    final rows = await db.query(
      Tables.songs,
      where: 'file_path = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SongModel.fromMap(rows.first);
  }

  /// 搜索歌曲（按歌名/歌手）
  Future<List<SongModel>> searchSongs(String keyword) async {
    final db = await _dbHelper.db;
    final rows = await db.query(
      Tables.songs,
      where: 'title LIKE ? OR artist LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: 'title ASC',
    );
    return rows.map((row) => SongModel.fromMap(row)).toList();
  }

  /// 删除歌曲（根据 ID）
  Future<void> deleteSong(String id) async {
    final db = await _dbHelper.db;
    await db.delete(
      Tables.songs,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取歌曲总数
  Future<int> getSongCount() async {
    final db = await _dbHelper.db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${Tables.songs}');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取总播放时长（秒）
  Future<int> getTotalDuration() async {
    final db = await _dbHelper.db;
    final result = await db.rawQuery(
        'SELECT SUM(duration) as total FROM ${Tables.songs}');
    final total = result.first['total'] as int?;
    return (total ?? 0) ~/ 1000; // 转换为秒
  }
}