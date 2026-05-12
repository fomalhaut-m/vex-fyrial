import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart' as logging;

import '../../data/database/database_helper.dart';
import '../../data/database/tables.dart';
import '../../data/models/song_model.dart';

/// 本地音乐扫描状态
class LocalMusicState {
  final List<SongModel> songs;
  final bool isScanning;
  final int scanProgress; // 当前扫描数
  final int scanTotal;    // 总数
  final String? error;
  final List<String> scanDirectories; // 扫描目录列表
  final bool hasPermission; // 是否有存储权限

  const LocalMusicState({
    this.songs = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.scanTotal = 0,
    this.error,
    this.scanDirectories = const [],
    this.hasPermission = false,
  });

  LocalMusicState copyWith({
    List<SongModel>? songs,
    bool? isScanning,
    int? scanProgress,
    int? scanTotal,
    String? error,
    List<String>? scanDirectories,
    bool? hasPermission,
  }) {
    return LocalMusicState(
      songs: songs ?? this.songs,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      scanTotal: scanTotal ?? this.scanTotal,
      error: error,
      scanDirectories: scanDirectories ?? this.scanDirectories,
      hasPermission: hasPermission ?? this.hasPermission,
    );
  }
}

/// 本地音乐 Notifier
/// 负责扫描设备上的音频文件，解析元数据，存入 SQLite
/// 支持 permission_handler + file_picker
class LocalMusicNotifier extends Notifier<LocalMusicState> {
  static const _tag = '[LocalMusicNotifier]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  final _dbHelper = DatabaseHelper.instance;

  @override
  LocalMusicState build() {
    _logger.info('[初始化] LocalMusicNotifier 开始初始化');
    // 初始加载
    Future.microtask(() => loadAllSongs());
    return const LocalMusicState();
  }

  /// 请求存储权限（带兜底）
  Future<bool> requestPermission() async {
    _logger.info('[权限] 请求存储权限...');

    try {
      // Android 13 以下需要存储权限
      PermissionStatus status;

      if (Platform.isAndroid) {
        // Android 13+ 使用 audio 权限
        status = await Permission.audio.request();
        if (status.isGranted) {
          _logger.info('[权限] audio 权限已授权');
          state = state.copyWith(hasPermission: true);
          return true;
        }

        // 尝试 storage 权限（Android 12 及以下）
        status = await Permission.storage.request();
        if (status.isGranted) {
          _logger.info('[权限] storage 权限已授权');
          state = state.copyWith(hasPermission: true);
          return true;
        }

        // 权限被拒绝但不是永久拒绝
        if (status.isDenied) {
          _logger.warning('[权限] 权限被拒绝（可以再次请求）');
          state = state.copyWith(hasPermission: false, error: '存储权限被拒绝');
          return false;
        }

        // 权限被永久拒绝
        if (status.isPermanentlyDenied) {
          _logger.severe('[权限] 权限被永久拒绝，需要用户手动设置');
          state = state.copyWith(
            hasPermission: false,
            error: '存储权限被永久拒绝，请在设置中开启',
          );
          return false;
        }
      }

      // 其他平台默认有权限（如 Linux）
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        _logger.info('[权限] 桌面平台默认有权限');
        state = state.copyWith(hasPermission: true);
        return true;
      }

      // 未知平台状态
      _logger.warning('[权限] 未知平台，假设有权限');
      state = state.copyWith(hasPermission: true);
      return true;
    } catch (e, s) {
      _logger.severe('[权限] 权限请求异常', e, s);
      state = state.copyWith(hasPermission: false, error: '权限检查异常');
      return false;
    }
  }

  /// 让用户选择音乐目录
  Future<String?> pickMusicDirectory() async {
    _logger.info('[文件] 让用户选择音乐目录...');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐目录',
      );

      if (result != null) {
        _logger.info('[文件] 用户选择目录: $result');
      } else {
        _logger.warning('[文件] 用户取消选择');
      }

      return result;
    } catch (e, s) {
      _logger.severe('[文件] pickMusicDirectory 异常', e, s);
      state = state.copyWith(error: '选择目录失败: $e');
      return null;
    }
  }

  /// 全量扫描本地音乐
  Future<int> scanAllMusic({
    void Function(int scanned, int total)? onProgress,
  }) async {
    _logger.info('[扫描] ===== scanAllMusic 开始 =====');

    if (state.isScanning) {
      _logger.warning('[扫描] 扫描中，禁止重复启动');
      return 0;
    }

    try {
      state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: 0, error: null);

      // 请求权限
      _logger.info('[扫描] 检查存储权限...');
      final hasPermission = await requestPermission();

      String? customDir;

      if (!hasPermission) {
        // 无权限，让用户选择目录
        _logger.warning('[扫描] 无存储权限，让用户选择目录');
        customDir = await pickMusicDirectory();

        if (customDir == null) {
          _logger.warning('[扫描] 用户取消选择，降级到默认目录扫描');
          final count = await _scanDefaultDirectories(onProgress: onProgress);
          state = state.copyWith(isScanning: false);
          return count;
        }
      }

      // 有权限或用户选择了自定义目录
      int count;
      if (customDir != null) {
        _logger.info('[扫描] 自定义目录: $customDir');
        count = await _scanDirectory(customDir, onProgress: onProgress);
      } else {
        // 默认：Android/iOS 使用媒体库扫描，Linux 使用默认目录
        count = await _scanDefaultDirectories(onProgress: onProgress);
      }

      _logger.info('[扫描] ===== scanAllMusic 完成，共 $count 首 =====');
      state = state.copyWith(isScanning: false);
      return count;
    } catch (e, s) {
      _logger.severe('[扫描] scanAllMusic 整体异常', e, s);
      state = state.copyWith(
        isScanning: false,
        error: '扫描失败: ${e.toString()}',
      );
      return 0;
    }
  }

  /// 扫描默认目录（Linux/macOS/Windows）
  Future<int> _scanDefaultDirectories({
    void Function(int scanned, int total)? onProgress,
  }) async {
    _logger.info('[扫描] ===== _scanDefaultDirectories 开始 =====');

    final home = Platform.environment['HOME'] ?? '/home';
    final musicDir = '$home/Music';
    final downloadDir = '$home/Downloads';
    final dirs = [musicDir, downloadDir];

    _logger.info('[扫描] 扫描目录: $dirs');

    final List<String> audioFiles = [];

    for (final dir in dirs) {
      try {
        final directory = Directory(dir);
        if (await directory.exists()) {
          _logger.info('[扫描] 目录存在，开始扫描: $dir');
          int fileCount = 0;

          await for (final entity in directory.list(recursive: true)) {
            if (entity is File && _isSupportedFormat(entity.path)) {
              audioFiles.add(entity.path);
              fileCount++;
            }
          }

          _logger.info('[扫描] $dir 扫描完成，找到 $fileCount 个音频文件');
        } else {
          _logger.warning('[扫描] 目录不存在或无法访问: $dir');
        }
      } catch (e, s) {
        _logger.severe('[扫描] 扫描目录 $dir 异常', e, s);
      }
    }

    _logger.info('[扫描] 默认目录扫描完成，共找到 ${audioFiles.length} 个音频文件');

    // 更新扫描目录
    state = state.copyWith(scanDirectories: dirs);

    return await _processAudioFiles(audioFiles, onProgress: onProgress);
  }

  /// 扫描指定目录
  Future<int> _scanDirectory(
    String dir, {
    void Function(int scanned, int total)? onProgress,
  }) async {
    _logger.info('[扫描] ===== _scanDirectory: $dir =====');

    final List<String> audioFiles = [];

    try {
      final directory = Directory(dir);
      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File && _isSupportedFormat(entity.path)) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e, s) {
      _logger.severe('[扫描] 扫描目录 $dir 异常', e, s);
    }

    _logger.info('[扫描] 扫描完成，共找到 ${audioFiles.length} 个音频文件');
    state = state.copyWith(scanDirectories: [dir]);

    return await _processAudioFiles(audioFiles, onProgress: onProgress);
  }

  /// 处理音频文件列表
  Future<int> _processAudioFiles(
    List<String> audioFiles, {
    void Function(int scanned, int total)? onProgress,
  }) async {
    int count = 0;
    final total = audioFiles.length;

    state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: total);

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

        state = state.copyWith(scanProgress: count);
        _logger.fine('[扫描] 处理进度: $count / $total');
        onProgress?.call(count, total);
      } catch (e, s) {
        _logger.severe('[扫描] 处理文件 $filePath 失败', e, s);
        // 单个文件失败不影响整体，继续处理下一个
      }
    }

    _logger.info('[扫描] ===== _processAudioFiles 完成，共 $count 首 =====');

    // 重新加载歌曲列表
    await loadAllSongs();

    state = state.copyWith(isScanning: false);
    return count;
  }

  /// 从文件路径提取文件名（不含扩展名）
  String _extractFileName(String filePath) {
    try {
      final name = filePath.split('/').last;
      final dotIndex = name.lastIndexOf('.');
      if (dotIndex > 0) return name.substring(0, dotIndex);
      return name;
    } catch (e) {
      _logger.severe('[工具] _extractFileName 异常: $filePath', e);
      return filePath;
    }
  }

  /// 生成歌曲唯一 ID（文件路径的 MD5 哈希）
  String _generateSongId(String filePath) {
    try {
      final bytes = md5.convert(utf8.encode(filePath));
      return bytes.toString();
    } catch (e) {
      _logger.severe('[工具] _generateSongId 异常: $filePath', e);
      // 回退到使用时间戳
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 判断是否支持该格式
  bool _isSupportedFormat(String uri) {
    try {
      final lower = uri.toLowerCase();
      return lower.endsWith('.mp3') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.flac') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.m4a');
    } catch (e) {
      return false;
    }
  }

  /// 插入或更新歌曲
  Future<void> _upsertSong(SongModel song) async {
    try {
      final db = await _dbHelper.db;
      await db.insert(
        Tables.songs,
        song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, s) {
      _logger.severe('[数据库] _upsertSong 异常: ${song.title}', e, s);
    }
  }

  /// 从数据库加载所有本地歌曲
  Future<void> loadAllSongs() async {
    _logger.info('[数据库] loadAllSongs() 开始');

    try {
      final db = await _dbHelper.db;
      final rows = await db.query(
        Tables.songs,
        orderBy: 'title ASC',
      );

      final songs = rows.map((row) => SongModel.fromMap(row)).toList();
      state = state.copyWith(songs: songs, error: null);
      _logger.info('[数据库] loadAllSongs 完成，共 ${songs.length} 首');
    } catch (e, s) {
      _logger.severe('[数据库] loadAllSongs 异常', e, s);
      state = state.copyWith(songs: [], error: '加载歌曲失败: $e');
    }
  }

  /// 搜索歌曲
  Future<List<SongModel>> searchSongs(String keyword) async {
    _logger.info('[搜索] searchSongs() keyword=$keyword');

    try {
      final db = await _dbHelper.db;
      final rows = await db.query(
        Tables.songs,
        where: 'title LIKE ? OR artist LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%'],
        orderBy: 'title ASC',
      );

      return rows.map((row) => SongModel.fromMap(row)).toList();
    } catch (e, s) {
      _logger.severe('[搜索] searchSongs 异常', e, s);
      return [];
    }
  }

  /// 删除歌曲
  Future<void> deleteSong(String id) async {
    _logger.info('[数据库] deleteSong() id=$id');

    try {
      final db = await _dbHelper.db;
      await db.delete(Tables.songs, where: 'id = ?', whereArgs: [id]);
      await loadAllSongs();
    } catch (e, s) {
      _logger.severe('[数据库] deleteSong 异常', e, s);
      state = state.copyWith(error: '删除失败: $e');
    }
  }

  /// 清除所有歌曲
  Future<void> clearAllSongs() async {
    _logger.info('[数据库] clearAllSongs()');

    try {
      final db = await _dbHelper.db;
      await db.delete(Tables.songs);
      state = state.copyWith(songs: []);
      _logger.info('[数据库] clearAllSongs 完成');
    } catch (e, s) {
      _logger.severe('[数据库] clearAllSongs 异常', e, s);
      state = state.copyWith(error: '清空失败: $e');
    }
  }
}

/// LocalMusicNotifier 的 Provider
final localMusicProvider =
    NotifierProvider<LocalMusicNotifier, LocalMusicState>(() {
  return LocalMusicNotifier();
});