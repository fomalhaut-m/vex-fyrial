import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/core/theme.dart';
import 'services/player_service.dart';
import 'services/local_music_service.dart';
import 'services/audio_handler_service.dart';

/// Vexfy App 入口文件
/// 整体结构说明：
/// - 使用 GetX 作为状态管理和路由管理
/// - 初始化全局服务（PlayerService、LocalMusicService）
/// - 注册全局控制器
/// - 配置主题色
void main() async {
  // 确保 Flutter 绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式（浅色背景，深色图标）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // 初始化全局服务
  await _initServices();

  // 启动 App
  runApp(const VexfyApp());
}

/// 初始化全局服务
/// 所有服务都注册为 GetX 单例，全局可访问
Future<void> _initServices() async {
  // 注册 PlayerService（播放器核心服务）
  // 使用 putAsSingleton 确保只创建一个实例
  Get.put(PlayerService.instance, permanent: true);

  // 注册 LocalMusicService（本地音乐扫描服务）
  Get.put(LocalMusicService.instance, permanent: true);

  // 启动音频服务（后台播放 + 通知栏）
  // 需要在 PlayerService 初始化之后调用
  await startAudioService();

  // TODO: 后续在这里注册更多服务
  // - StorageService（本地存储）
  // - OSSSyncService（OSS 同步）
  // - PlayStatsService（播放统计）
}

/// Vexfy App 根组件
class VexfyApp extends StatelessWidget {
  const VexfyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // 应用标题
      title: 'Vexfy',

      // 关闭调试标记（生产环境）
      debugShowCheckedModeBanner: false,

      // 默认主题色
      theme: AppTheme.lightTheme,

      // 暗色主题（暂不使用）
      darkTheme: AppTheme.darkTheme,

      // 路由配置
      initialRoute: AppPages.initial,

      // GetX 路由页面注册
      getPages: AppPages.routes,

      // 默认过渡动画
      defaultTransition: Transition.cupertino,
    );
  }
}