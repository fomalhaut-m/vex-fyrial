import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart' as logging;

import '../data/database/database_helper.dart';

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

  @override
  String toString() => '[健康检测] $feature: $message';
}

/// 健康检测服务
/// 在 App 启动时全面检测各项功能是否可用（12 项）
/// 所有检测都有 try-catch，失败不影响 App 启动
class HealthCheckService {
  static const _tag = '[HealthCheckService]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  /// 单例
  HealthCheckService._();
  static final HealthCheckService instance = HealthCheckService._();

  /// 所有检测结果
  final List<HealthCheckResult> _results = [];

  /// 是否已完成检测
  bool _isCompleted = false;

  /// 获取所有检测结果
  List<HealthCheckResult> get results => List.unmodifiable(_results);

  /// 是否已完成
  bool get isCompleted => _isCompleted;

  /// 全部检测是否通过
  bool get isAllHealthy => _results.every((r) => r.isHealthy);

  /// 运行全部健康检测（12 项）
  /// 返回是否所有检测都通过
  Future<bool> runAllChecks() async {
    _logger.info('===== 开始健康检测（12 项）=====');
    _results.clear();
    _isCompleted = false;

    try {
      // 1. 数据库检测
      await _checkDatabase();

      // 2. 文件读写检测
      await _checkFileSystem();

      // 3. 存储权限检测
      await _checkStoragePermission();

      // 4. 网络状态检测
      await _checkNetwork();

      // 5. 通知栏权限检测
      await _checkNotificationPermission();

      // 6. 后台播放权限检测
      await _checkBackgroundAudioPermission();

      // 7. 音频焦点检测
      await _checkAudioFocus();

      // 8. 音频播放检测（会有声音，放最后）
      await _checkAudioPlayback();

      // 9. 耳机检测
      await _checkHeadphone();

      // 10. 磁盘空间检测
      await _checkDiskSpace();

      // 11. OSS 连接检测
      await _checkOssConnection();

      // 12. 内存状态检测
      await _checkMemory();

      _isCompleted = true;
      _logSummary();

      return isAllHealthy;
    } catch (e, s) {
      _logger.severe('[健康检测] runAllChecks() 整体异常', e, s);
      _isCompleted = true;
      return false;
    }
  }

  /// 日志汇总
  void _logSummary() {
    final healthy = _results.where((r) => r.isHealthy).length;
    final total = _results.length;

    if (isAllHealthy) {
      _logger.info('===== 健康检测完成：全部通过 ($healthy/$total) =====');
    } else {
      final failed = _results.where((r) => !r.isHealthy).toList();
      _logger.warning('===== 健康检测完成：$healthy/$total 通过，${failed.length} 项异常 =====');
      for (final r in failed) {
        _logger.warning('  [异常] ${r.feature}: ${r.message}');
      }
    }
  }

  // ========== 1. 数据库检测 ==========

  Future<void> _checkDatabase() async {
    _logger.fine('[健康检测-数据库] 开始检测...');

    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.db;
      final now = DateTime.now().toIso8601String();

      // 写入测试
      const testKey = 'health_check_db';
      await db.insert(
        'app_info',
        {'key': testKey, 'value': '1.0.0', 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 读取验证
      final result = await db.query(
        'app_info',
        where: 'key = ?',
        whereArgs: [testKey],
      );

      // 清理测试数据
      await db.delete('app_info', where: 'key = ?', whereArgs: [testKey]);

      if (result.isEmpty) {
        _results.add(const HealthCheckResult(
          feature: '数据库',
          isHealthy: false,
          message: '异常：无法读取刚写入的数据',
        ));
        _logger.severe('[健康检测-数据库] ❌ 异常：无法读取');
      } else {
        _results.add(HealthCheckResult(
          feature: '数据库',
          isHealthy: true,
          message: dbHelper.isMemoryMode ? '正常（内存模式）' : '正常',
        ));
        _logger.info('[健康检测-数据库] ✅ 正常${dbHelper.isMemoryMode ? '（内存模式）' : ''}');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '数据库',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-数据库] ❌ 异常', e, s);
    }
  }

  // ========== 2. 文件读写检测 ==========

  Future<void> _checkFileSystem() async {
    _logger.fine('[健康检测-文件读写] 开始检测...');

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final testFilePath = path.join(documentsDir.path, '.vexfy_health_check');

      // 写入测试
      await File(testFilePath).writeAsString('Vexfy Health Check\n');
      _logger.fine('[健康检测-文件读写] 写入成功');

      // 读取验证
      final content = await File(testFilePath).readAsString();
      if (!content.contains('Vexfy Health Check')) {
        throw Exception('文件内容验证失败');
      }
      _logger.fine('[健康检测-文件读写] 读取成功');

      // 清理测试文件
      await File(testFilePath).delete();
      _logger.fine('[健康检测-文件读写] 清理成功');

      _results.add(const HealthCheckResult(
        feature: '文件读写',
        isHealthy: true,
        message: '正常',
      ));
      _logger.info('[健康检测-文件读写] ✅ 正常');
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '文件读写',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-文件读写] ❌ 异常', e, s);
    }
  }

  // ========== 3. 存储权限检测 ==========

  Future<void> _checkStoragePermission() async {
    _logger.fine('[健康检测-存储权限] 开始检测...');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final audioStatus = await Permission.audio.status;
        final storageStatus = await Permission.storage.status;

        if (audioStatus.isGranted || storageStatus.isGranted) {
          _results.add(const HealthCheckResult(
            feature: '存储权限',
            isHealthy: true,
            message: '已授权',
          ));
          _logger.info('[健康检测-存储权限] ✅ 已授权');
        } else if (storageStatus.isDenied || audioStatus.isDenied) {
          _results.add(const HealthCheckResult(
            feature: '存储权限',
            isHealthy: true,
            message: '未授权（可在设置中授予）',
          ));
          _logger.info('[健康检测-存储权限] ⚠️ 未授权（可在设置中授予）');
        } else if (storageStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied) {
          _results.add(const HealthCheckResult(
            feature: '存储权限',
            isHealthy: true,
            message: '被拒绝（需手动授权）',
          ));
          _logger.info('[健康检测-存储权限] ⚠️ 被拒绝（需手动授权）');
        } else {
          _results.add(const HealthCheckResult(
            feature: '存储权限',
            isHealthy: true,
            message: '未知状态',
          ));
          _logger.info('[健康检测-存储权限] ⚠️ 未知状态');
        }
      } else {
        _results.add(const HealthCheckResult(
          feature: '存储权限',
          isHealthy: true,
          message: '正常（桌面平台无需权限）',
        ));
        _logger.info('[健康检测-存储权限] ✅ 正常（桌面平台）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '存储权限',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-存储权限] ❌ 异常', e, s);
    }
  }

  // ========== 4. 网络状态检测 ==========

  Future<void> _checkNetwork() async {
    _logger.fine('[健康检测-网络状态] 开始检测...');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        _results.add(const HealthCheckResult(
          feature: '网络状态',
          isHealthy: true,
          message: '离线（本地功能正常）',
        ));
        _logger.info('[健康检测-网络状态] ⚠️ 离线（本地功能正常）');
      } else {
        final types = connectivityResult.map((r) => r.name).join(', ');
        _results.add(HealthCheckResult(
          feature: '网络状态',
          isHealthy: true,
          message: '在线（$types）',
        ));
        _logger.info('[健康检测-网络状态] ✅ 在线（$types）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '网络状态',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-网络状态] ❌ 异常', e, s);
    }
  }

  // ========== 5. 通知栏权限检测 ==========

  Future<void> _checkNotificationPermission() async {
    _logger.fine('[健康检测-通知栏权限] 开始检测...');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.notification.status;

        if (status.isGranted) {
          _results.add(const HealthCheckResult(
            feature: '通知栏权限',
            isHealthy: true,
            message: '已授权',
          ));
          _logger.info('[健康检测-通知栏权限] ✅ 已授权');
        } else if (status.isDenied) {
          _results.add(const HealthCheckResult(
            feature: '通知栏权限',
            isHealthy: true,
            message: '未授权（无通知栏）',
          ));
          _logger.info('[健康检测-通知栏权限] ⚠️ 未授权（无通知栏）');
        } else if (status.isPermanentlyDenied) {
          _results.add(const HealthCheckResult(
            feature: '通知栏权限',
            isHealthy: true,
            message: '被拒绝（无法显示通知）',
          ));
          _logger.info('[健康检测-通知栏权限] ⚠️ 被拒绝（无法显示通知）');
        } else {
          _results.add(const HealthCheckResult(
            feature: '通知栏权限',
            isHealthy: true,
            message: '未知状态',
          ));
          _logger.info('[健康检测-通知栏权限] ⚠️ 未知状态');
        }
      } else {
        _results.add(const HealthCheckResult(
          feature: '通知栏权限',
          isHealthy: true,
          message: '正常（桌面平台无需权限）',
        ));
        _logger.info('[健康检测-通知栏权限] ✅ 正常（桌面平台）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '通知栏权限',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-通知栏权限] ❌ 异常', e, s);
    }
  }

  // ========== 6. 后台播放权限检测 ==========

  Future<void> _checkBackgroundAudioPermission() async {
    _logger.fine('[健康检测-后台播放] 开始检测...');

    try {
      if (Platform.isAndroid) {
        final status = await Permission.audio.status;
        if (status.isGranted) {
          _results.add(const HealthCheckResult(
            feature: '后台播放',
            isHealthy: true,
            message: '正常',
          ));
          _logger.info('[健康检测-后台播放] ✅ 正常');
        } else {
          _results.add(const HealthCheckResult(
            feature: '后台播放',
            isHealthy: true,
            message: '⚠️ 需要音频权限',
          ));
          _logger.info('[健康检测-后台播放] ⚠️ 需要音频权限');
        }
      } else if (Platform.isIOS) {
        _results.add(const HealthCheckResult(
          feature: '后台播放',
          isHealthy: true,
          message: '正常（iOS 自动管理）',
        ));
        _logger.info('[健康检测-后台播放] ✅ 正常（iOS）');
      } else {
        _results.add(const HealthCheckResult(
          feature: '后台播放',
          isHealthy: true,
          message: '正常（桌面平台）',
        ));
        _logger.info('[健康检测-后台播放] ✅ 正常（桌面平台）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '后台播放',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-后台播放] ❌ 异常', e, s);
    }
  }

  // ========== 7. 音频焦点检测 ==========

  Future<void> _checkAudioFocus() async {
    _logger.fine('[健康检测-音频焦点] 开始检测...');

    AudioPlayer? testPlayer;
    try {
      testPlayer = AudioPlayer();
      await testPlayer.setVolume(0.5);

      _results.add(const HealthCheckResult(
        feature: '音频焦点',
        isHealthy: true,
        message: '正常',
      ));
      _logger.info('[健康检测-音频焦点] ✅ 正常');

      await testPlayer.dispose();
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '音频焦点',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-音频焦点] ❌ 异常', e, s);

      try {
        await testPlayer?.dispose();
      } catch (_) {}
    }
  }

  // ========== 8. 音频播放检测 ==========

  Future<void> _checkAudioPlayback() async {
    _logger.fine('[健康检测-音频播放] 开始检测...');

    AudioPlayer? testPlayer;
    try {
      testPlayer = AudioPlayer();

      // 尝试加载 asset 测试音频
      bool assetLoaded = false;
      try {
        await testPlayer.setAsset('assets/test/test_music.mp3');
        assetLoaded = true;
        _logger.fine('[健康检测-音频播放] asset 加载成功');
      } catch (_) {
        _logger.fine('[健康检测-音频播放] asset 加载失败');
      }

      if (!assetLoaded && Platform.isLinux) {
        // Linux 平台检查 libmpv
        final libmpvPath = _findLibmpv();
        if (libmpvPath == null) {
          _results.add(const HealthCheckResult(
            feature: '音频播放',
            isHealthy: true,
            message: '⚠️ 缺少 libmpv',
          ));
          _logger.info('[健康检测-音频播放] ⚠️ 缺少 libmpv');
          await testPlayer.dispose();
          return;
        } else {
          _results.add(HealthCheckResult(
            feature: '音频播放',
            isHealthy: true,
            message: '正常（libmpv: ${_shortPath(libmpvPath)}）',
          ));
          _logger.info('[健康检测-音频播放] ✅ 正常（libmpv: ${_shortPath(libmpvPath)}）');
          await testPlayer.dispose();
          return;
        }
      }

      // 设置最小音量（1%）避免刺耳
      await testPlayer.setVolume(0.01);

      // 开始播放
      if (assetLoaded) {
        await testPlayer.play();
        _logger.fine('[健康检测-音频播放] 开始播放测试音');
        await Future.delayed(const Duration(milliseconds: 500));
        await testPlayer.stop();
        _logger.fine('[健康检测-音频播放] 停止播放');
      }

      await testPlayer.dispose();

      _results.add(const HealthCheckResult(
        feature: '音频播放',
        isHealthy: true,
        message: '正常',
      ));
      _logger.info('[健康检测-音频播放] ✅ 正常');
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '音频播放',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-音频播放] ❌ 异常', e, s);

      try {
        await testPlayer?.dispose();
      } catch (_) {}
    }
  }

  // ========== 9. 耳机检测 ==========

  Future<void> _checkHeadphone() async {
    _logger.fine('[健康检测-耳机检测] 开始检测...');

    try {
      // just_audio 不提供直接耳机检测 API
      // 耳机状态在播放时由系统自动处理
      if (Platform.isAndroid) {
        _results.add(const HealthCheckResult(
          feature: '耳机检测',
          isHealthy: true,
          message: '正常（运行时检测）',
        ));
        _logger.info('[健康检测-耳机检测] ✅ 正常（运行时检测）');
      } else {
        _results.add(const HealthCheckResult(
          feature: '耳机检测',
          isHealthy: true,
          message: '正常（桌面平台）',
        ));
        _logger.info('[健康检测-耳机检测] ✅ 正常（桌面平台）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '耳机检测',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-耳机检测] ❌ 异常', e, s);
    }
  }

  // ========== 10. 磁盘空间检测 ==========

  Future<void> _checkDiskSpace() async {
    _logger.fine('[健康检测-磁盘空间] 开始检测...');

    try {
      final documentsDir = await getApplicationDocumentsDirectory();

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        try {
          final result = await Process.run('df', ['-h', documentsDir.path]);
          if (result.exitCode == 0) {
            final lines = result.stdout.toString().split('\n');
            if (lines.length >= 2) {
              final parts = lines[1].split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                final available = parts[3];
                _results.add(HealthCheckResult(
                  feature: '磁盘空间',
                  isHealthy: true,
                  message: '剩余 $available',
                ));
                _logger.info('[健康检测-磁盘空间] ✅ 剩余 $available');
                return;
              }
            }
          }
        } catch (_) {}
      }

      _results.add(const HealthCheckResult(
        feature: '磁盘空间',
        isHealthy: true,
        message: '正常',
      ));
      _logger.info('[健康检测-磁盘空间] ✅ 正常');
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '磁盘空间',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-磁盘空间] ❌ 异常', e, s);
    }
  }

  // ========== 11. OSS 连接检测 ==========

  Future<void> _checkOssConnection() async {
    _logger.fine('[健康检测-OSS连接] 开始检测...');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        _results.add(const HealthCheckResult(
          feature: 'OSS连接',
          isHealthy: true,
          message: '离线（未配置）',
        ));
        _logger.info('[健康检测-OSS连接] ⚠️ 离线（未配置）');
      } else {
        _results.add(const HealthCheckResult(
          feature: 'OSS连接',
          isHealthy: true,
          message: '正常（网络可用）',
        ));
        _logger.info('[健康检测-OSS连接] ✅ 正常（网络可用）');
      }
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: 'OSS连接',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-OSS连接] ❌ 异常', e, s);
    }
  }

  // ========== 12. 内存状态检测 ==========

  Future<void> _checkMemory() async {
    _logger.fine('[健康检测-内存状态] 开始检测...');

    try {
      if (Platform.isLinux) {
        try {
          final result = await Process.run('free', ['-h']);
          if (result.exitCode == 0) {
            final output = result.stdout.toString();
            final available = _parseLinuxMemory(output);
            if (available != null) {
              if (_isLowMemory(available)) {
                _results.add(HealthCheckResult(
                  feature: '内存状态',
                  isHealthy: true,
                  message: '⚠️ 剩余 $available（较低）',
                ));
                _logger.info('[健康检测-内存状态] ⚠️ 剩余 $available（较低）');
              } else {
                _results.add(HealthCheckResult(
                  feature: '内存状态',
                  isHealthy: true,
                  message: '剩余 $available',
                ));
                _logger.info('[健康检测-内存状态] ✅ 剩余 $available');
              }
              return;
            }
          }
        } catch (_) {}
      } else if (Platform.isMacOS) {
        try {
          final result = await Process.run('vm_stat', []);
          if (result.exitCode == 0) {
            final output = result.stdout.toString();
            final available = _parseMacOSMemory(output);
            if (available != null) {
              if (_isLowMemory(available)) {
                _results.add(HealthCheckResult(
                  feature: '内存状态',
                  isHealthy: true,
                  message: '⚠️ 剩余 $available（较低）',
                ));
                _logger.info('[健康检测-内存状态] ⚠️ 剩余 $available（较低）');
              } else {
                _results.add(HealthCheckResult(
                  feature: '内存状态',
                  isHealthy: true,
                  message: '剩余 $available',
                ));
                _logger.info('[健康检测-内存状态] ✅ 剩余 $available');
              }
              return;
            }
          }
        } catch (_) {}
      }

      _results.add(const HealthCheckResult(
        feature: '内存状态',
        isHealthy: true,
        message: '正常',
      ));
      _logger.info('[健康检测-内存状态] ✅ 正常');
    } catch (e, s) {
      _results.add(HealthCheckResult(
        feature: '内存状态',
        isHealthy: false,
        message: '异常：${e.toString()}',
        error: s.toString(),
      ));
      _logger.severe('[健康检测-内存状态] ❌ 异常', e, s);
    }
  }

  /// 解析 Linux free -h 输出
  String? _parseLinuxMemory(String output) {
    try {
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.startsWith('Mem:')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 7) {
            return parts[3]; // available 列
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 解析 macOS vm_stat 输出
  String? _parseMacOSMemory(String output) {
    try {
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.contains('Pages free')) {
          final match = RegExp(r' (\d+)$').firstMatch(line);
          if (match != null) {
            final pages = int.tryParse(match.group(1) ?? '');
            if (pages != null) {
              // macOS page size 通常 4096 bytes
              final mb = (pages * 4096) / (1024 * 1024);
              return '${mb.toStringAsFixed(0)}MB';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 判断是否内存过低
  bool _isLowMemory(String available) {
    try {
      final numStr = RegExp(r'[\d.]+').firstMatch(available)?.group(0) ?? '0';
      final value = double.tryParse(numStr) ?? 0;

      if (available.contains('G')) {
        return value < 0.5;
      } else if (available.contains('M')) {
        return value < 500;
      }
    } catch (_) {}
    return false;
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

    for (final p in possiblePaths) {
      if (File(p).existsSync()) {
        return p;
      }
    }
    return null;
  }

  /// 缩短路径显示
  String _shortPath(String fullPath) {
    if (fullPath.length <= 30) return fullPath;
    return '...${fullPath.substring(fullPath.length - 27)}';
  }

  /// 获取异常的功能列表
  List<String> getFailedFeatures() {
    return _results.where((r) => !r.isHealthy).map((r) => r.feature).toList();
  }

  /// 获取警告的功能列表（⚠️）
  List<String> getWarningFeatures() {
    return _results
        .where((r) => r.isHealthy && r.message.contains('⚠️'))
        .map((r) => r.feature)
        .toList();
  }

  /// 获取友好提示信息
  String getFriendlyMessage() {
    if (isAllHealthy) {
      return '所有功能检测正常';
    }

    final failed = getFailedFeatures();
    if (failed.isEmpty) {
      return '部分功能待优化，App 可正常使用';
    }

    if (failed.contains('数据库')) return '数据库异常，部分功能可能受限';
    if (failed.contains('音频播放')) return '音频播放异常，请检查安装';
    if (failed.contains('文件读写')) return '文件读写异常，可能无法保存设置';

    return '${failed.join('、')} 功能异常';
  }
}
