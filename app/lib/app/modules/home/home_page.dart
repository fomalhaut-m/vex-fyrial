import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/tab_index_provider.dart';
import '../../../widgets/mini_player.dart';
import '../player/player_tab.dart';
import '../playlist/playlist_tab.dart';
import '../stats/stats_tab.dart';
import '../settings/settings_tab.dart';

/// 首页 - 底部 4 Tab 导航
/// 包含：播放器 | 播放列表 | 统计 | 设置
/// 全局 MiniPlayer 常驻在 Tab 栏上方
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabIndexProvider);

    // Tab 列表
    const List<Widget> tabs = [
      PlayerTab(),
      PlaylistTab(),
      StatsTab(),
      SettingsTab(),
    ];

    return Scaffold(
      // Tab 内容区域
      body: IndexedStack(
        index: tabState.currentIndex,
        children: tabs,
      ),

      // 全局迷你播放器（常驻在底部 Tab 栏上方）
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MiniPlayer：在 Tab 0（播放器）时不显示
          const MiniPlayer(),

          // 底部 Tab 导航栏
          BottomNavigationBar(
            currentIndex: tabState.currentIndex,
            onTap: (index) {
              ref.read(tabIndexProvider.notifier).switchTab(index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.play_circle_outline),
                activeIcon: Icon(Icons.play_circle_filled),
                label: '播放器',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music),
                label: '播放列表',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }
}