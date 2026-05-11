import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:sqflite/sqflite.dart';

import '../data/database/database_helper.dart';
import '../data/database/tables.dart';
import '../data/models/song_model.dart';

/// 全局日志工具
/// 统一管理日志输出，便于后续切换到文件日志或统计服务
class AppLogger {
  static const _tag = '[Vexfy]';

  static void d(String tag, String msg) =>
      print('$_tag$tag $msg');

  static void e(String tag, String msg, [Object? error, StackTrace? stack]) {
    print('$_tag$tag [ERROR] $msg');
    if (error != null) print('$_tag$tag 错误: $error');
    if (stack != null) print('$_tag$tag 堆栈: ${stack.toString().split('\n').take(5).join('\n')}');
  }

  static void i(String tag, String msg) =>
      print('$_tag$tag $msg');
}

/// 本地音乐扫描服务
/// 负责扫描设备上的音频文件，解析元数据，存入 SQLite
/// 支持格式：MP3、AAC、FLAC、WAV、MP4
class LocalMusicService {
  static const _tag = '[LocalMusicService]';

  // 单例模式
  LocalMusicService._();
  static final LocalMusicService instance = LocalMusicService._();

  final oaq.OnAudioQuery _audioQuery = oaq.OnAudioQuery();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 检查权限并请求
  /// 返回 true 表示有权限
  Future<bool> requestPermission() async {
    try {
      AppLogger.d(_tag, '请求存储权限...');
      final result = await _audioQuery.checkAndRequest();
      AppLogger.d(_tag, '权限结果: $result');
      return result;
    } catch (e, s) {
      AppLogger.e(_tag, 'checkAndRequest 异常', e, s);
      return false;
    }
  }

  /// 全量扫描本地音乐
  /// 递归扫描配置的目录，解析 ID3 标签，存入数据库
  /// 返回扫描到的歌曲数量
  Future<int> scanAllMusic({
    void Function(int scanned, int total)? onProgress,
  }) async {
    AppLogger.i(_tag, '===== scanAllMusic 开始 =====');

    try {
      // 请求权限
      AppLogger.d(_tag, '检查存储权限...');
      final hasPermission = await requestPermission();

      if (!hasPermission) {
        AppLogger.i(_tag, '权限不足，切换 Linux 目录扫描');
        return _scanLinuxDirectory(onProgress: onProgress);
      }

      // Android/iOS：使用 on_audio_query 查询媒体库
      AppLogger.d(_tag, '使用 on_audio_query 查询媒体库...');
      final songs = await _audioQuery.querySongs(
        sortType: oaq.SongSortType.TITLE,
        orderType: oaq.OrderType.ASC_OR_SMALLER,
        uriType: oaq.UriType.EXTERNAL,
        ignoreCase: true,
      );

      AppLogger.d(_tag, 'on_audio_query 返回 ${songs.length} 个文件');

      int count = 0;
      final total = songs.length;

      for (final song in songs) {
        try {
          final uri = song.data ?? song.uri ?? '';
          if (!_isSupportedFormat(uri)) continue;

          final songModel = _fromAudioSongModel(song);
          await _upsertSong(songModel);
          count++;
          AppLogger.d(_tag, '扫描进度: $count / $total');
          onProgress?.call(count, total);
        } catch (e, s) {
          AppLogger.e(_tag, '处理单个文件异常: ${song.uri ?? song.data}', e, s);
        }
      }

      AppLogger.i(_tag, '===== scanAllMusic 完成，共 $count 首 =====');
      return count;
    } catch (e, s) {
      AppLogger.e(_tag, 'scanAllMusic 整体异常，降级到 Linux 扫描', e, s);
      AppLogger.i(_tag, '切换 Linux 目录扫描');
      return _scanLinuxDirectory(onProgress: onProgress);
    }
  }

  /// Linux 桌面版文件扫描（降级方案）
  /// 扫描用户音乐目录
  Future<int> _scanLinuxDirectory({
    void Function(int scanned, int total)? onProgress,
  }) async {
    AppLogger.i(_tag, '===== _scanLinuxDirectory 开始 =====');

    final home = Platform.environment['HOME'] ?? '/home';
    final musicDir = '$home/Music';
    final downloadDir = '$home/Downloads';
    final dirs = [musicDir, downloadDir];

    AppLogger.d(_tag, '扫描目录: $dirs');

    final List<String> audioFiles = [];

    for (final dir in dirs) {
      try {
        final directory = Directory(dir);
        if (await directory.exists()) {
          AppLogger.d(_tag, '目录存在，开始扫描: $dir');
          int fileCount = 0;
          await for (final entity in directory.list(recursive: true)) {
            if (entity is File && _isSupportedFormat(entity.path)) {
              audioFiles.add(entity.path);
              fileCount++;
            }
          }
          AppLogger.d(_tag, '$dir 扫描完成，找到 $fileCount 个音频文件');
        } else {
          AppLogger.d(_tag, '目录不存在或无法访问: $dir');
        }
      } catch (e, s) {
        AppLogger.e(_tag, '扫描目录 $dir 异常', e, s);
      }
    }

    AppLogger.d(_tag, 'Linux 扫描完成，共找到 ${audioFiles.length} 个音频文件');

    int count = 0;
    final total = audioFiles.length;

    for (final filePath in audioFiles) {
      try {
        final songModel = SongModel(
          id: _generateSongId(filePath),
          title: _extractFileName(filePath),
          artist: '未知歌手',
          album: null,
          duration: 0,
          coverUrl: null,
          source: SongSource.local,
          filePath: filePath,
          onlineUrl: null,
          lyrics: null,
          isFavorite: false,
          playCount: 0,
          createdAt: DateTime.now(),
        );

        await _upsertSong(songModel);
        count++;
        AppLogger.d(_tag, '处理进度: $count / $total');
        onProgress?.call(count, total);
      } catch (e, s) {
        AppLogger.e(_tag, '处理文件 $filePath 失败', e, s);
      }
    }

    AppLogger.i(_tag, '===== _scanLinuxDirectory 完成，共 $count 首 =====');
    return count;
  }

  /// 从文件路径提取文件名（不含扩展名）
  String _extractFileName(String filePath) {
    final name = filePath.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) return name.substring(0, dotIndex);
    return name;
  }

  /// 将 on_audio_query 的 SongModel 转为我们的 SongModel
  SongModel _fromAudioSongModel(oaq.SongModel audioSong) {
    final filePath = audioSong.data ?? audioSong.uri ?? '';

    return SongModel(
      id: _generateSongId(filePath),
      title: audioSong.title ?? '未知歌曲',
      artist: audioSong.artist ?? '未知歌手',
      album: audioSong.album,
      duration: audioSong.duration ?? 0,
      coverUrl: null,
      source: SongSource.local,
      filePath: filePath,
      onlineUrl: null,
      lyrics: null,
      isFavorite: false,
      playCount: 0,
      fileSize: audioSong.size,
      mimeType: null,
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
        lower.endsWith('.m4a');
  }

  /// 插入或更新歌曲
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

  /// 搜索歌曲
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

  /// 删除歌曲
  Future<void> deleteSong(String id) async {
    final db = await _dbHelper.db;
    await db.delete(Tables.songs, where: 'id = ?', whereArgs: [id]);
  }
}
