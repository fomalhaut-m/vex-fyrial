import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logging/logging.dart' as logging;

import 'app/routes/app_pages.dart';
import 'app/core/theme.dart';
import 'services/player_service.dart';
import 'services/local_music_service.dart';
import 'services/audio_handler_service.dart';
import 'data/database/database_helper.dart';

final _logger = logging.Logger('Vexfy');

void _setupLogger() {
  logging.hierarchicalLoggingEnabled = true;
  _logger.level = logging.Level.ALL;
  
  _logger.onRecord.listen((record) {
    final levelStr = _levelString(record.level).padRight(7);
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
    print('[$timeStr] [Vexfy] $levelStr ${record.message}');
    if (record.error != null) {
      print('       错误: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('       堆栈: ${record.stackTrace.toString().split('\n').take(5).join('\n       ')}');
    }
  });
}

String _levelString(logging.Level level) {
  if (level.value <= 300) return 'DEBUG';
  if (level.value <= 500) return 'INFO ';
  if (level.value <= 700) return 'WARN ';
  return 'ERROR';
}

/// Vexfy App 入口文件
void main() async {
  _setupLogger();

  // ===== 全局异常处理（必须是最先设置的）=====

  // Flutter widget 层异常（如 build() 里的错误）
  FlutterError.onError = (details) {
    _logger.severe('[FlutterError] Widget 异常: ${details.exception}');
    if (details.stack != null) {
      _logger.severe('[FlutterError]', details.stack);
    }
    FlutterError.presentError(details);
  };

  // 原生平台异常（如 platform channel 错误）
  PlatformDispatcher.instance.onError = (error, stack) {
    _logger.severe('[Platform] 平台异常: $error');
    _logger.severe('[Platform]', stack);
    return true;
  };

  _logger.info('[main] ===== Vexfy App 启动 =====');

  try {
    // 确保 Flutter 绑定初始化完成
    WidgetsFlutterBinding.ensureInitialized();
    _logger.fine('[main] Flutter 绑定初始化完成');

      // 设置状态栏样式
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ));

      // 初始化全局服务
      await _initServices();

      // 启动 App
      runApp(const VexfyApp());
    } catch (e, s) {
      _logger.severe('[main] main() 启动异常: $e');
      _logger.severe('[main]', s);
      // 显示错误界面，不闪退
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('启动异常: $e\n详见日志', textAlign: TextAlign.center),
          ),
        ),
      ));
    }
}

/// 初始化全局服务
Future<void> _initServices() async {
  _logger.fine('[main] 开始初始化全局服务...');

  try {
    // 注册 PlayerService（播放器核心服务）
    Get.put(PlayerService.instance, permanent: true);
    _logger.fine('[main] PlayerService 注册完成');

    // 注册 LocalMusicService（本地音乐扫描服务）
    Get.put(LocalMusicService.instance, permanent: true);
    _logger.fine('[main] LocalMusicService 注册完成');

    // 数据库健康检查
    final dbHealthy = await DatabaseHelper.instance.healthCheck();
    if (!dbHealthy) {
      _logger.severe('[main] 数据库健康检查失败，SQLite 可能无法正常工作');
    }

    // 执行完整的启动检查
    await StartupValidator.instance.runAllChecks();

    // 启动音频服务（后台播放 + 通知栏）
    await startAudioService();
    _logger.fine('[main] AudioService 启动完成');
  } catch (e, s) {
    _logger.severe('[main] _initServices() 异常: $e');
    _logger.severe('[main]', s);
    rethrow;
  }
}

/// Vexfy App 根组件
class VexfyApp extends StatelessWidget {
  const VexfyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Vexfy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
    );
  }
}
