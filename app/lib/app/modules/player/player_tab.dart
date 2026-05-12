import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/player_provider.dart';
import '../../../router/app_router.dart';

/// Tab 1：播放器页面
/// 显示当前播放的封面、歌词、播控按钮
class PlayerTab extends ConsumerWidget {
  const PlayerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final song = playerState.currentSong;

    return Scaffold(
      // 内容区域，使用 SafeArea 避免被状态栏遮挡
      body: SafeArea(
        child: LayoutBuilder(
          // 响应式布局，适配不同屏幕
          builder: (context, constraints) {
            // 根据可用高度动态调整封面大小
            final coverSize = (constraints.maxHeight * 0.35).clamp(180.0, 300.0);

            return SingleChildScrollView(
              // 小屏幕时可滚动，防止溢出
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    // 上方空余空间
                    SizedBox(height: constraints.maxHeight * 0.05),

                    // 封面图片
                    GestureDetector(
                      onTap: () {
                        // 点击打开全屏播放器
                        context.push(AppRoutes.player);
                      },
                      child: Container(
                        width: coverSize,
                        height: coverSize,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: song?.coverUrl != null
                              ? Image.network(
                                  song!.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildDefaultCover(),
                                )
                              : _buildDefaultCover(),
                        ),
                      ),
                    ),

                    SizedBox(height: constraints.maxHeight * 0.03),

                    // 歌曲名称
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        song?.title ?? '未选择歌曲',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 歌手名
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        song?.artist ?? '请选择一首歌曲播放',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFB3B3B3),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 进度条 + 时间
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.03),
                          // 进度条
                          SliderTheme(
                            data: Theme.of(context).sliderTheme.copyWith(
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  trackHeight: 4,
                                ),
                            child: Slider(
                              value: playerState.progressPercent.clamp(0.0, 1.0),
                              onChanged: (value) {
                                playerNotifier.seekToPercent(value);
                              },
                            ),
                          ),

                          // 时间显示
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                playerState.currentTimeString,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3B3B3),
                                ),
                              ),
                              Text(
                                playerState.totalTimeString,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3B3B3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 控制栏：上一首 | 播放/暂停 | 下一首
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 随机播放按钮
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: playerState.isShuffle
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFFB3B3B3),
                            ),
                            onPressed: () => playerNotifier.toggleShuffle(),
                          ),

                          // 上一首
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 40),
                            onPressed: () => playerNotifier.previous(),
                          ),

                          // 播放/暂停按钮
                          playerState.isLoading
                              ? const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1DB954),
                                    strokeWidth: 3,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 64,
                                    color: const Color(0xFF1DB954),
                                  ),
                                  onPressed: () =>
                                      playerNotifier.togglePlayPause(),
                                ),

                          // 下一首
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 40),
                            onPressed: () => playerNotifier.next(),
                          ),

                          // 循环模式按钮
                          IconButton(
                            icon: Icon(
                              _getRepeatIcon(playerState.playMode),
                              color: playerState.playMode != PlayMode.sequential
                                  ? const Color(0xFF1DB954)
                                  : const Color(0xFFB3B3B3),
                            ),
                            onPressed: () => playerNotifier.cycleRepeatMode(),
                          ),
                        ],
                      ),
                    ),

                    // 底部留白，防止最后一屏内容贴边
                    SizedBox(height: constraints.maxHeight * 0.05),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建默认封面（无封面时显示）
  Widget _buildDefaultCover() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: Colors.grey,
        ),
      ),
    );
  }

  /// 根据播放模式返回对应的图标
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