import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/core/theme.dart';
import '../providers/tab_index_provider.dart';
import '../providers/player_provider.dart';
import '../router/app_router.dart';

/// 全局迷你播放器组件
/// 常驻在底部 Tab 栏上方，有播放内容时自动显示
/// 在 PlayerTab（第1个Tab）时不显示
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final tabState = ref.watch(tabIndexProvider);

    // 无播放内容时隐藏
    final song = playerState.currentSong;
    if (song == null) {
      return const SizedBox.shrink();
    }

    // 在 PlayerTab（Tab 0）时不显示迷你播放器
    if (tabState.currentIndex == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        // 点击切换到 Tab 0（播放器）
        ref.read(tabIndexProvider.notifier).switchTab(0);
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
            LinearProgressIndicator(
              value: playerState.progressPercent.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.grey[200],
              color: AppTheme.primaryGreen,
            ),

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
                    IconButton(
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                        color: AppTheme.primaryGreen,
                      ),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).togglePlayPause(),
                    ),

                    // 下一首按钮
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 28, color: Color(0xFFB3B3B3)),
                      onPressed: () =>
                          ref.read(playerProvider.notifier).next(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}