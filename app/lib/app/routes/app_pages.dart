import 'package:get/get.dart';

import 'app_routes.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/home_page.dart';
import '../modules/player/player_page.dart';

/// GetX 路由配置
/// 所有页面在此注册，路由跳转通过 Get.toNamed() 实现
class AppPages {
  AppPages._();

  /// 初始路由
  static const initial = Routes.home;

  /// 路由列表
  static final routes = [
    // 主页（含底部 4 Tab）
    GetPage(
      name: Routes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),

    // 全屏播放页
    GetPage(
      name: Routes.player,
      page: () => const PlayerPage(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}