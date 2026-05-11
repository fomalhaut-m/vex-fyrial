import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app/routes/app_pages.dart';
import 'app/core/theme.dart';
import 'services/player_service.dart';
import 'services/local_music_service.dart';
import 'services/audio_handler_service.dart';

/// 全局日志工具
class AppLogger {
  static const _tag = '[Vexfy]';

  static void d(String tag, String msg) =>
      print('$_tag$tag $msg');

  static void e(String tag, String msg, [Object? error, StackTrace? stack]) {
    print('$_tag$tag [ERROR] $msg');
    if (error != null) print('$_tag$tag 错误: $error');
    if (stack != null) {
      final lines = stack.toString().split('\n').take(8).join('\n');
      print('$_tag$tag 堆栈:\n$lines');
    }
  }

  static void i(String tag, String msg) =>
      print('$_tag$tag $msg');
}

/// Vexfy App 入口文件
void main() async {
  // ===== 全局异常处理（必须是最先设置的）=====

  // Flutter widget 层异常（如 build() 里的错误）
  FlutterError.onError = (details) {
    AppLogger.e('[FlutterError]', 'Widget 异常', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // 原生平台异常（如 platform channel 错误）
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('[Platform]', '平台异常', error, stack);
    return true;
  };

  AppLogger.i('[main]', '===== Vexfy App 启动 =====');

  try {
    // 确保 Flutter 绑定初始化完成
    WidgetsFlutterBinding.ensureInitialized();
    AppLogger.d('[main]', 'Flutter 绑定初始化完成');

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
      AppLogger.e('[main]', 'main() 启动异常', e, s);
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
  AppLogger.d('[main]', '开始初始化全局服务...');

  try {
    // 为 Linux 和 Windows 初始化 just_audio 媒体后端
    JustAudioMediaKit.ensureInitialized(
      linux: true,
      windows: true,
    );
    AppLogger.d('[main]', 'JustAudioMediaKit 初始化完成');

    // 注册 PlayerService（播放器核心服务）
    Get.put(PlayerService.instance, permanent: true);
    AppLogger.d('[main]', 'PlayerService 注册完成');

    // 注册 LocalMusicService（本地音乐扫描服务）
    Get.put(LocalMusicService.instance, permanent: true);
    AppLogger.d('[main]', 'LocalMusicService 注册完成');

    // 启动音频服务（后台播放 + 通知栏）
    await startAudioService();
    AppLogger.d('[main]', 'AudioService 启动完成');
  } catch (e, s) {
    AppLogger.e('[main]', '_initServices() 异常', e, s);
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
