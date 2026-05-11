import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/player_service.dart';
import '../../../widgets/mini_player.dart';
import '../player/player_tab.dart';
import '../playlist/playlist_tab.dart';
import '../stats/stats_tab.dart';
import '../settings/settings_tab.dart';

/// 首页 - 底部 4 Tab 导航
/// 包含：播放器 | 播放列表 | 统计 | 设置
/// 全局 MiniPlayer 常驻在 Tab 栏上方
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 当前 Tab 索引
  int _currentIndex = 0;

  /// Tab 列表
  final List<Widget> _tabs = const [
    PlayerTab(),
    PlaylistTab(),
    StatsTab(),
    SettingsTab(),
  ];

  /// Tab 标题
  final List<String> _tabTitles = const [
    '播放器',
    '播放列表',
    '统计',
    '设置',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tab 内容区域
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      // 全局迷你播放器（常驻在底部 Tab 栏上方）
      // MiniPlayer 会自动监听 PlayerService 的播放状态
      // 有歌曲时自动显示，无歌曲时自动隐藏
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // MiniPlayer：有播放内容时显示
          const MiniPlayer(),

          // 底部 Tab 导航栏
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              // Tab 1：播放器
              BottomNavigationBarItem(
                icon: Icon(Icons.play_circle_outline),
                activeIcon: Icon(Icons.play_circle_filled),
                label: '播放器',
              ),

              // Tab 2：播放列表
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music),
                label: '播放列表',
              ),

              // Tab 3：统计
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '统计',
              ),

              // Tab 4：设置
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