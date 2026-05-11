import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/player_service.dart';
import '../app/core/theme.dart';
import '../app/core/tab_controller.dart';

/// 全局迷你播放器组件
/// 常驻在底部 Tab 栏上方，有播放内容时自动显示
/// 在 PlayerTab（第1个Tab）时不显示
/// 点击切换到 Tab 1（播放器）
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerService = Get.find<PlayerService>();

    // 无播放内容时隐藏
    return Obx(() {
      final song = playerService.currentSong.value;
      if (song == null) {
        return const SizedBox.shrink();
      }

      // 在 PlayerTab 时不显示迷你播放器
      // 通过 HomePageController 判断当前 Tab
      if (Get.isRegistered<HomePageController>()) {
        final controller = HomePageController.to;
        if (controller.currentIndex.value == 0) {
          return const SizedBox.shrink();
        }
      }

      return GestureDetector(
        onTap: () {
          // 点击切换到 Tab 0（播放器）
          if (Get.isRegistered<HomePageController>()) {
            HomePageController.to.switchTab(0);
          }
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 进度条（2dp 高度）
              Obx(() {
                final pos = playerService.position.value;
                final dur = playerService.duration.value;
                final percent = dur > 0 ? pos / dur : 0.0;

                return LinearProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: Colors.grey[200],
                  color: AppTheme.primaryGreen,
                );
              }),

              // 播放器内容
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // 封面
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: song.coverUrl != null
                              ? Image.network(
                                  song.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.music_note, color: Colors.grey),
                                )
                              : const Icon(Icons.music_note, color: Colors.grey),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // 歌曲信息
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // 播放/暂停按钮
                      Obx(() => IconButton(
                            icon: Icon(
                              playerService.isPlaying.value ? Icons.pause : Icons.play_arrow,
                              size: 32,
                              color: AppTheme.primaryGreen,
                            ),
                            onPressed: () => playerService.togglePlayPause(),
                          )),

                      // 下一首按钮
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 28, color: Color(0xFFB3B3B3)),
                        onPressed: () => playerService.next(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
