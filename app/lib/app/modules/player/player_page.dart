import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/tab_index_provider.dart';
import '../../core/theme.dart';

/// 全屏播放页面
/// 从 Tab 1 的"点击封面"或"点击 MiniPlayer"跳转
/// 显示封面大图 + 歌词视图 + 完整播控栏
class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);

    return Scaffold(
      // 背景色
      backgroundColor: Colors.white,

      // 页面内容
      body: SafeArea(
        child: Column(
          children: [
            // 顶部操作栏
            _buildTopBar(context),

            // 中间区域：封面或歌词
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // 点击关闭页面
                  context.pop();
                },
                onVerticalDragEnd: (details) {
                  // 下滑关闭页面
                  if (details.primaryVelocity! > 300) {
                    context.pop();
                  }
                },
                child: _buildCoverView(playerState.currentSong),
              ),
            ),

            // 歌曲名称 + 歌手
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    playerState.currentSong?.title ?? '未选择歌曲',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playerState.currentSong?.artist ?? '未知歌手',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildProgressSlider(ref, playerState),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        playerState.currentTimeString,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        playerState.totalTimeString,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 控制栏
            _buildControlBar(ref, playerState),

            // 底部提示手势条
            const SizedBox(height: 8),
            _buildGestureHint(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 顶部操作栏
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            onPressed: () => context.pop(),
          ),

          // 更多按钮（暂不实现）
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO: 显示更多菜单
            },
          ),
        ],
      ),
    );
  }

  /// 进度条 Slider
  Widget _buildProgressSlider(WidgetRef ref, FyrialPlayerState state) {
    return SliderTheme(
      data: const SliderThemeData(
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 4,
      ),
      child: Slider(
        value: state.progressPercent.clamp(0.0, 1.0),
        onChanged: (value) {
          ref.read(playerProvider.notifier).seekToPercent(value);
        },
      ),
    );
  }

  /// 封面视图
  Widget _buildCoverView(dynamic song) {
    return Container(
      margin: const EdgeInsets.all(32),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song?.coverUrl != null
                  ? Image.network(
                      song!.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultCover(),
                    )
                  : _buildDefaultCover(),
            ),
          ),
        ),
      ),
    );
  }

  /// 默认封面
  Widget _buildDefaultCover() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.music_note,
          size: 100,
          color: Colors.grey,
        ),
      ),
    );
  }

  /// 控制栏
  Widget _buildControlBar(WidgetRef ref, FyrialPlayerState state) {
    final notifier = ref.read(playerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 随机播放
          IconButton(
            icon: Icon(
              Icons.shuffle,
              color: state.isShuffle
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary,
            ),
            onPressed: () => notifier.toggleShuffle(),
          ),

          // 上一首
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 44),
            onPressed: () => notifier.previous(),
          ),

          // 播放/暂停
          state.isLoading
              ? const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGreen,
                    strokeWidth: 3,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 64,
                    color: AppTheme.primaryGreen,
                  ),
                  onPressed: () => notifier.togglePlayPause(),
                ),

          // 下一首
          IconButton(
            icon: const Icon(Icons.skip_next, size: 44),
            onPressed: () => notifier.next(),
          ),

          // 循环模式
          IconButton(
            icon: Icon(
              _getRepeatIcon(state.playMode),
              color: state.playMode != PlayMode.sequential
                  ? AppTheme.primaryGreen
                  : AppTheme.textSecondary,
            ),
            onPressed: () => notifier.cycleRepeatMode(),
          ),
        ],
      ),
    );
  }

  /// 底部手势提示
  Widget _buildGestureHint() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// 获取循环模式图标
  IconData _getRepeatIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.listLoop:
        return Icons.repeat;
      case PlayMode.singleLoop:
        return Icons.repeat_one;
      case PlayMode.sequential:
        return Icons.repeat;
      case PlayMode.shuffle:
        return Icons.repeat;
    }
  }
}