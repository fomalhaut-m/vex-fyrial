import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/player_service.dart';
import '../../routes/app_routes.dart';

/// Tab 1：播放器页面
/// 显示当前播放的封面、歌词、播控按钮
class PlayerTab extends StatelessWidget {
  const PlayerTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取 PlayerService（已在 main.dart 注册）
    final playerService = Get.find<PlayerService>();

    return Scaffold(
      // 内容区域，使用 SafeArea 避免被状态栏遮挡
      body: SafeArea(
        child: Obx(() {
          final song = playerService.currentSong.value;
          final isPlaying = playerService.isPlaying.value;
          final isLoading = playerService.isLoading.value;

          return Column(
            children: [
              // 上方空余空间
              const SizedBox(height: 40),

              // 封面图片
              // 播放时旋转动画，暂停时停止
              GestureDetector(
                onTap: () {
                  // 点击封面：跳转到全屏播放页
                  Get.toNamed(Routes.player);
                },
                child: Container(
                  width: 280,
                  height: 280,
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

              const SizedBox(height: 32),

              // 歌曲名称
              Text(
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

              const SizedBox(height: 8),

              // 歌手名
              Text(
                song?.artist ?? '请选择一首歌曲播放',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFB3B3B3),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // 进度条 + 时间
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // 进度条
                    Obx(() {
                      final pos = playerService.position.value;
                      final dur = playerService.duration.value;
                      final percent =
                          dur > 0 ? pos / dur : 0.0;

                      return SliderTheme(
                        data: Theme.of(context).sliderTheme.copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 4,
                            ),
                        child: Slider(
                          value: percent.clamp(0.0, 1.0),
                          onChanged: (value) {
                            playerService.seekToPercent(value);
                          },
                        ),
                      );
                    }),

                    // 时间显示
                    Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              playerService.currentTimeString,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB3B3B3),
                              ),
                            ),
                            Text(
                              playerService.totalTimeString,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB3B3B3),
                              ),
                            ),
                          ],
                        )),
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
                    Obx(() => IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: playerService.isShuffle.value
                                ? const Color(0xFF1DB954)
                                : const Color(0xFFB3B3B3),
                          ),
                          onPressed: () {
                            playerService.toggleShuffle();
                          },
                        )),

                    // 上一首
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 40),
                      onPressed: () {
                        playerService.previous();
                      },
                    ),

                    // 播放/暂停按钮
                    isLoading
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
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 64,
                              color: const Color(0xFF1DB954),
                            ),
                            onPressed: () {
                              playerService.togglePlayPause();
                            },
                          ),

                    // 下一首
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 40),
                      onPressed: () {
                        playerService.next();
                      },
                    ),

                    // 循环模式按钮
                    Obx(() => IconButton(
                          icon: Icon(
                            _getRepeatIcon(playerService.playMode.value),
                            color: playerService.playMode.value !=
                                    PlayMode.sequential
                                ? const Color(0xFF1DB954)
                                : const Color(0xFFB3B3B3),
                          ),
                          onPressed: () {
                            playerService.cycleRepeatMode();
                          },
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        }),
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