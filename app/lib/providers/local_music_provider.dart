import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

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
/// 注意：数据库操作已废弃，此类仅保留权限请求和文件选择功能
/// TODO: 待迁移到 Hive
class LocalMusicNotifier extends Notifier<LocalMusicState> {
  static const _tag = '[LocalMusicNotifier]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  @override
  LocalMusicState build() {
    _logger.info('[初始化] LocalMusicNotifier 开始初始化');
    _logger.warning('[警告] 数据库操作已废弃，请使用 Hive');
    // 初始加载（暂时返回空列表）
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

  /// 扫描指定目录中的音频文件
  Future<int> scanDirectory(String directoryPath) async {
    _logger.info('[扫描] 开始扫描目录: $directoryPath');

    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        _logger.severe('[扫描] 目录不存在: $directoryPath');
        state = state.copyWith(error: '目录不存在');
        return 0;
      }

      state = state.copyWith(isScanning: true, scanProgress: 0, scanTotal: 0, error: null);

      // 支持的音频文件扩展名
      final audioExtensions = {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma'};
      
      final songs = <SongModel>[];
      int scannedCount = 0;

      // 递归扫描目录
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (audioExtensions.contains(ext)) {
            try {
              // 获取文件信息
              final stat = await entity.stat();
              final fileSize = stat.size;
              
              // 创建歌曲模型（使用文件名作为标题）
              final fileName = path.basenameWithoutExtension(entity.path);
              final song = SongModel(
                id: const Uuid().v4(),
                title: fileName,
                artist: '未知歌手',
                duration: 0, // TODO: 后续集成 audio_metadata_reader 获取真实时长
                filePath: entity.path,
                source: SongSource.local,
                fileSize: fileSize,
                mimeType: _getMimeType(ext),
                createdAt: DateTime.now(),
              );

              songs.add(song);
              scannedCount++;

              // 更新进度
              state = state.copyWith(
                scanProgress: scannedCount,
                songs: List.unmodifiable(songs),
              );

              _logger.fine('[扫描] 找到歌曲: ${song.title}');
            } catch (e) {
              _logger.warning('[扫描] 处理文件失败: ${entity.path}, 错误: $e');
            }
          }
        }
      }

      // 扫描完成
      state = state.copyWith(
        isScanning: false,
        scanTotal: scannedCount,
        scanProgress: scannedCount,
        songs: List.unmodifiable(songs),
      );

      _logger.info('[扫描] 扫描完成，共找到 $scannedCount 首歌曲');
      return scannedCount;
    } catch (e, s) {
      _logger.severe('[扫描] 扫描异常', e, s);
      state = state.copyWith(
        isScanning: false,
        error: '扫描失败: $e',
      );
      return 0;
    }
  }

  /// 根据文件扩展名获取 MIME 类型
  String? _getMimeType(String ext) {
    switch (ext) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.flac':
        return 'audio/flac';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.m4a':
        return 'audio/mp4';
      case '.wma':
        return 'audio/x-ms-wma';
      default:
        return null;
    }
  }

  /// 全量扫描本地音乐（已废弃 - 数据库操作）
  Future<int> scanAllMusic({
    void Function(int scanned, int total)? onProgress,
  }) async {
    _logger.warning('[废弃] scanAllMusic() 已废弃，数据库操作已移除');
    _logger.warning('[提示] 待迁移到 Hive 后重新实现');
    state = state.copyWith(error: '扫描功能暂未实现（等待 Hive 迁移）');
    return 0;
  }

  /// 从数据库加载所有本地歌曲（已废弃）
  Future<void> loadAllSongs() async {
    _logger.warning('[废弃] loadAllSongs() 已废弃，数据库操作已移除');
    _logger.warning('[提示] 待迁移到 Hive 后重新实现');
    state = state.copyWith(songs: [], error: null);
  }

  /// 搜索歌曲（已废弃）
  Future<List<SongModel>> searchSongs(String keyword) async {
    _logger.warning('[废弃] searchSongs() 已废弃，数据库操作已移除');
    return [];
  }

  /// 删除歌曲（已废弃）
  Future<void> deleteSong(String id) async {
    _logger.warning('[废弃] deleteSong() 已废弃，数据库操作已移除');
  }

  /// 清除所有歌曲（已废弃）
  Future<void> clearAllSongs() async {
    _logger.warning('[废弃] clearAllSongs() 已废弃，数据库操作已移除');
    state = state.copyWith(songs: []);
  }
}

/// LocalMusicNotifier 的 Provider
final localMusicProvider =
    NotifierProvider<LocalMusicNotifier, LocalMusicState>(() {
  return LocalMusicNotifier();
});
