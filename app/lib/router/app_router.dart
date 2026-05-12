import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/modules/home/home_page.dart';
import '../app/modules/player/player_page.dart';

/// 路由名称常量
abstract class AppRoutes {
  AppRoutes._();

  /// 主页
  static const String home = '/';

  /// 全屏播放页
  static const String player = '/player';
}

/// Vexfy 路由配置（go_router）
/// 所有页面在此注册，路由跳转通过 context.go() 实现
class AppRouter {
  AppRouter._();

  /// 路由列表
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      // 主页（含底部 4 Tab）
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // 全屏播放页
      GoRoute(
        path: AppRoutes.player,
        name: 'player',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PlayerPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('路由错误: ${state.error}'),
      ),
    ),
  );
}