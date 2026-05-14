import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../data/models/song_model.dart';
import 'local_music_state.dart';

/// ═══════════════════════════════════════════════════════════════════════════
///
///   🎵 本地音乐管理器
///   Local Music Manager
///
///   负责本地音乐的权限请求、目录选择、文件扫描等功能
///   Manages local music: permission requests, directory selection, file scanning
///
/// ═══════════════════════════════════════════════════════════════════════════
class LocalMusicNotifier extends Notifier<LocalMusicState> {
  static const String _tag = '📀 LocalMusicNotifier';

  static final logging.Logger _logger = logging.Logger(_tag)
    ..level = logging.Level.ALL
    ..onRecord = _formatLogRecord;

  static void _formatLogRecord(logging.LogRecord record) {
    final level = record.level.name.padRight(7);
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final message = record.message;
    final error = record.error;

    final prefix = switch (record.level) {
      logging.Level.SEVERE => '❌',
      logging.Level.WARNING => '⚠️ ',
      logging.Level.INFO => 'ℹ️ ',
      logging.Level.FINE => '🔍',
      _ => '  ',
    };

    final output = StringBuffer();
    output.writeln('┌─ $prefix [$level] $timestamp');
    output.writeln('│  $message');
    if (error != null) {
      output.writeln('│  🔤 Error: $error');
    }
    if (record.stackTrace != null) {
      output.writeln('│  📍 StackTrace: ${record.stackTrace}');
    }
    output.write('└─');

    print(output.toString());
  }

  @override
  LocalMusicState build() {
    _logInfo('✨', 'LocalMusicNotifier 开始初始化');
    _logWarning('⚠️', '数据库操作已废弃，请使用 Hive 替代');
    Future.microtask(() => loadAllSongs());
    return const LocalMusicState();
  }

  /// ═══════════════════════════════════════════════════════════════════════
  ///
  ///   🔐 权限请求
  ///   Permission Request
  ///
  ///   请求存储权限，支持 Android 和桌面平台
  ///   Requests storage permission for Android and desktop platforms
  ///
  ///   @return bool 权限是否授予成功
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  Future<bool> requestPermission() async {
    _logInfo('🔐', '正在请求存储权限...');

    try {
      PermissionStatus status;

      if (Platform.isAndroid) {
        _logFine('🤖', '检测到 Android 平台');

        status = await Permission.audio.request();
        if (status.isGranted) {
          _logInfo('✅', 'audio 权限已授予');
          state = state.copyWith(hasPermission: true);
          return true;
        }

        status = await Permission.storage.request();
        if (status.isGranted) {
          _logInfo('✅', 'storage 权限已授予');
          state = state.copyWith(hasPermission: true);
          return true;
        }

        if (status.isDenied) {
          _logWarning('⛔', '权限被拒绝（可再次请求）');
          state = state.copyWith(
            hasPermission: false,
            error: '存储权限被拒绝',
          );
          return false;
        }

        if (status.isPermanentlyDenied) {
          _logError('🚫', '权限被永久拒绝，请在设置中开启', null);
          state = state.copyWith(
            hasPermission: false,
            error: '存储权限被永久拒绝，请在设置中开启',
          );
          return false;
        }
      }

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        _logInfo('🖥️', '桌面平台默认拥有权限');
        state = state.copyWith(hasPermission: true);
        return true;
      }

      _logWarning('❓', '未知平台，假设拥有权限');
      state = state.copyWith(hasPermission: true);
      return true;
    } catch (e, s) {
      _logError('💥', '权限请求异常', e, s);
      state = state.copyWith(hasPermission: false, error: '权限检查异常');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  ///
  ///   📁 目录选择
  ///   Directory Selection
  ///
  ///   打开系统文件选择器，让用户选择音乐目录
  ///   Opens system file picker for user to select music directory
  ///
  ///   @return String? 选择的目录路径，取消则返回 null
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  Future<String?> pickMusicDirectory() async {
    _logInfo('📂', '打开目录选择器...');

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐目录',
      );

      if (result != null) {
        _logInfo('📁', '用户选择目录: $result');
      } else {
        _logWarning('↩️', '用户取消选择');
      }

      return result;
    } catch (e, s) {
      _logError('💥', 'pickMusicDirectory 异常', e, s);
      state = state.copyWith(error: '选择目录失败: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  ///
  ///   🔍 目录扫描
  ///   Directory Scanning
  ///
  ///   递归扫描指定目录中的音频文件
  ///   Recursively scans audio files in specified directory
  ///
  ///   @param directoryPath 要扫描的目录路径
  ///   @return int 扫描到的歌曲数量
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  Future<int> scanDirectory(String directoryPath) async {
    _logInfo('🔍', '开始扫描目录: $directoryPath');

    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        _logError('❌', '目录不存在: $directoryPath', null, null);
        state = state.copyWith(error: '目录不存在');
        return 0;
      }

      state = state.copyWith(
        isScanning: true,
        scanProgress: 0,
        scanTotal: 0,
        error: null,
      );

      const audioExtensions = {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma'};

      final songs = <SongModel>[];
      int scannedCount = 0;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (audioExtensions.contains(ext)) {
            try {
              final stat = await entity.stat();
              final fileSize = stat.size;
              final fileName = path.basenameWithoutExtension(entity.path);

              final song = SongModel(
                id: const Uuid().v4(),
                title: fileName,
                artist: '未知歌手',
                duration: 0,
                filePath: entity.path,
                source: SongSource.local,
                fileSize: fileSize,
                mimeType: _getMimeType(ext),
                createdAt: DateTime.now(),
              );

              songs.add(song);
              scannedCount++;

              state = state.copyWith(
                scanProgress: scannedCount,
                songs: List.unmodifiable(songs),
              );

              _logFine('🎵', '找到歌曲: ${song.title} [${song.mimeType}]');
            } catch (e) {
              _logWarning('⚠️', '处理文件失败: ${entity.path}, 错误: $e');
            }
          }
        }
      }

      state = state.copyWith(
        isScanning: false,
        scanTotal: scannedCount,
        scanProgress: scannedCount,
        songs: List.unmodifiable(songs),
      );

      _logInfo('🎉', '扫描完成，共找到 $scannedCount 首歌曲');
      return scannedCount;
    } catch (e, s) {
      _logError('💥', '扫描异常', e, s);
      state = state.copyWith(isScanning: false, error: '扫描失败: $e');
      return 0;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  ///
  ///   📋 MIME 类型映射
  ///   MIME Type Mapping
  ///
  ///   根据文件扩展名获取对应的 MIME 类型
  ///   Maps file extension to corresponding MIME type
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  String? _getMimeType(String ext) {
    return switch (ext) {
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.flac' => 'audio/flac',
      '.aac' => 'audio/aac',
      '.ogg' => 'audio/ogg',
      '.m4a' => 'audio/mp4',
      '.wma' => 'audio/x-ms-wma',
      _ => null,
    };
  }

  Future<int> scanAllMusic({
    void Function(int scanned, int total)? onProgress,
  }) async {
    _logWarning('🗑️', 'scanAllMusic() 已废弃，数据库操作已移除');
    _logInfo('💡', '待迁移到 Hive 后重新实现');
    state = state.copyWith(error: '扫描功能暂未实现（等待 Hive 迁移）');
    return 0;
  }

  Future<void> loadAllSongs() async {
    _logWarning('🗑️', 'loadAllSongs() 已废弃，数据库操作已移除');
    _logInfo('💡', '待迁移到 Hive 后重新实现');
    state = state.copyWith(songs: [], error: null);
  }

  Future<List<SongModel>> searchSongs(String keyword) async {
    _logWarning('🗑️', 'searchSongs() 已废弃，数据库操作已移除');
    return [];
  }

  Future<void> deleteSong(String id) async {
    _logWarning('🗑️', 'deleteSong() 已废弃，数据库操作已移除');
  }

  Future<void> clearAllSongs() async {
    _logWarning('🗑️', 'clearAllSongs() 已废弃，数据库操作已移除');
    state = state.copyWith(songs: []);
  }

  void _logInfo(String emoji, String message) {
    _logger.info('[$emoji] $message');
  }

  void _logWarning(String emoji, String message) {
    _logger.warning('[$emoji] $message');
  }

  void _logFine(String emoji, String message) {
    _logger.fine('[$emoji] $message');
  }

  void _logError(String emoji, String message, Object? error, [StackTrace? stackTrace]) {
    _logger.severe('[$emoji] $message', error, stackTrace);
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
///
///   🏭 Provider 工厂函数
///   Provider Factory Function
///
///   创建 LocalMusicNotifier 的 NotifierProvider
///   Creates NotifierProvider for LocalMusicNotifier
///
/// ═══════════════════════════════════════════════════════════════════════════
final localMusicProvider = NotifierProvider<LocalMusicNotifier, LocalMusicState>(() {
  return LocalMusicNotifier();
});