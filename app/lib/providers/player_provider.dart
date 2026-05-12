import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart' as logging;

import '../data/models/song_model.dart';
import '../services/audio_handler_service.dart';

/// 播放模式枚举
enum PlayMode {
  listLoop,   // 列表循环
  singleLoop, // 单曲循环
  shuffle,    // 随机播放
  sequential, // 顺序播放
}

/// 播放器状态
class VexfyPlayerState {
  final List<SongModel> playlist;
  final int currentIndex;
  final SongModel? currentSong;
  final bool isPlaying;
  final bool isLoading;
  final int position; // 毫秒
  final int duration; // 毫秒
  final PlayMode playMode;
  final bool isShuffle;
  final String? error; // 当前错误信息

  const VexfyPlayerState({
    this.playlist = const [],
    this.currentIndex = -1,
    this.currentSong,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = 0,
    this.duration = 0,
    this.playMode = PlayMode.listLoop,
    this.isShuffle = false,
    this.error,
  });

  VexfyPlayerState copyWith({
    List<SongModel>? playlist,
    int? currentIndex,
    SongModel? currentSong,
    bool? isPlaying,
    bool? isLoading,
    int? position,
    int? duration,
    PlayMode? playMode,
    bool? isShuffle,
    String? error,
  }) {
    return VexfyPlayerState(
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      isShuffle: isShuffle ?? this.isShuffle,
      error: error, // 允许清空错误
    );
  }

  /// 播放进度百分比（0.0 ~ 1.0）
  double get progressPercent {
    if (duration == 0) return 0;
    return position / duration;
  }

  /// 当前已播放时间字符串
  String get currentTimeString => _formatDuration(position);

  /// 总时长字符串
  String get totalTimeString => _formatDuration(duration);

  String _formatDuration(int milliseconds) {
    final d = Duration(milliseconds: milliseconds);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 播放器 Notifier - 全局单例
/// 封装 just_audio，提供播放控制、队列管理、进度监听
class PlayerNotifier extends Notifier<VexfyPlayerState> {
  static final _logger = logging.Logger('PlayerNotifier')..level = logging.Level.ALL;

  /// just_audio 的 AudioPlayer 实例
  late final AudioPlayer _player;

  /// 播放器是否已初始化成功
  bool _isInitialized = false;

  /// 对外暴露 player 实例（供 AudioHandler 访问）
  AudioPlayer get player => _player;

  /// 内部队列（用于 shuffle 模式打乱顺序）
  List<int>? _shuffledIndices;

  @override
  VexfyPlayerState build() {
    _initPlayer();
    ref.onDispose(() {
      _dispose();
    });
    return const VexfyPlayerState();
  }

  /// 初始化播放器（带异常兜底）
  Future<void> _initPlayer() async {
    _logger.info('[初始化] 开始初始化播放器...');

    try {
      _player = AudioPlayer();

      // 监听播放状态变化
      _player.playerStateStream.listen(
        (audioState) {
          state = state.copyWith(
            isPlaying: audioState.playing,
            isLoading: audioState.processingState == ProcessingState.loading ||
                audioState.processingState == ProcessingState.buffering,
          );
          if (audioState.processingState == ProcessingState.completed) {
            _logger.info('[状态] 播放完成');
            _onSongComplete();
          }
        },
        onError: (e, s) {
          _logger.severe('[播放状态] 监听异常', e, s);
          state = state.copyWith(error: '播放状态监听异常: $e');
        },
      );

      // 监听播放器错误
      _player.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          _logger.severe('[播放器] 异常', e, st);
          state = state.copyWith(error: '播放器异常: $e');
        },
      );

      // 监听播放位置变化
      _player.positionStream.listen(
        _onPositionChanged,
        onError: (e, s) {
          _logger.severe('[位置] 监听异常', e, s);
        },
      );

      // 监听总时长
      _player.durationStream.listen(
        _onDurationChanged,
        onError: (e, s) {
          _logger.severe('[时长] 监听异常', e, s);
        },
      );

      _isInitialized = true;
      _logger.info('[初始化] 播放器初始化成功');

      // 关联 AudioHandler
      try {
        audioHandler.attachPlayerNotifier(this);
        _logger.info('[初始化] AudioHandler 关联成功');
      } catch (e, s) {
        _logger.warning('[初始化] AudioHandler 关联失败（继续运行）', e, s);
      }
    } catch (e, s) {
      _logger.severe('[初始化] 播放器初始化失败', e, s);
      state = state.copyWith(error: '播放器初始化失败，请重启 App');
    }
  }

  void _onPositionChanged(Duration pos) {
    try {
      state = state.copyWith(position: pos.inMilliseconds);
    } catch (e, s) {
      _logger.severe('[位置] 更新异常', e, s);
    }
  }

  void _onDurationChanged(Duration? dur) {
    try {
      if (dur != null) {
        state = state.copyWith(duration: dur.inMilliseconds);
      }
    } catch (e, s) {
      _logger.severe('[时长] 更新异常', e, s);
    }
  }

  /// 通知 AudioHandler 当前歌曲变化
  void notifyCurrentSongChanged(SongModel? song) {
    try {
      audioHandler.updateCurrentSong(song);
    } catch (e, s) {
      _logger.warning('[通知] AudioHandler 更新失败', e, s);
    }
  }

  /// 播放指定歌曲
  Future<void> playSong(SongModel song, {bool playNow = true}) async {
    _logger.info('[播放] playSong() 入参: song=${song.title}, playNow=$playNow');

    if (!_isInitialized) {
      _logger.severe('[播放] 播放器未初始化');
      state = state.copyWith(error: '播放器暂不可用');
      return;
    }

    try {
      // 如果歌曲不在队列中，先加入队列
      int idx = state.playlist.indexWhere((s) => s.id == song.id);
      List<SongModel> newPlaylist = state.playlist;
      if (idx < 0) {
        newPlaylist = [...state.playlist, song];
        idx = newPlaylist.length - 1;
      }

      state = state.copyWith(playlist: newPlaylist, error: null);

      // 切换到该歌曲
      await _switchToIndex(idx, playNow: playNow);
    } catch (e, s) {
      _logger.severe('[播放] playSong 异常', e, s);
      state = state.copyWith(error: '播放失败: ${e.toString()}');
    }
  }

  /// 切换到指定索引的歌曲
  Future<void> _switchToIndex(int index, {bool playNow = true}) async {
    if (index < 0 || index >= state.playlist.length) {
      _logger.warning('[切换] 索引无效: $index');
      return;
    }

    try {
      final song = state.playlist[index];
      _logger.info('[切换] 切换到: ${song.title} (index=$index)');

      state = state.copyWith(
        currentIndex: index,
        currentSong: song,
      );

      // 通知 AudioHandler
      notifyCurrentSongChanged(song);

      // 加载音频源
      final filePath = song.filePath;
      if (filePath == null) {
        _logger.warning('[加载] 文件路径为空: ${song.title}');
        state = state.copyWith(error: '文件路径为空');
        return;
      }

      // 检查文件是否存在
      if (!File(filePath).existsSync()) {
        _logger.severe('[加载] 文件不存在: $filePath');
        state = state.copyWith(error: '文件不存在或已删除');
        return;
      }

      state = state.copyWith(isLoading: true, error: null);

      await _player.setFilePath(filePath);
      _logger.info('[加载] 加载成功: ${song.title}');

      if (playNow) {
        await _player.play();
        _logger.info('[播放] 开始播放: ${song.title}');
      }

      state = state.copyWith(isLoading: false);
    } catch (e, s) {
      _logger.severe('[加载] 加载失败', e, s);
      state = state.copyWith(
        isLoading: false,
        error: '加载失败: ${e.toString()}',
      );
    }
  }

  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    _logger.fine('[控制] togglePlayPause()');

    if (!_isInitialized) {
      _logger.severe('[控制] 播放器未初始化');
      return;
    }

    try {
      if (state.isPlaying) {
        await _player.pause();
        _logger.info('[控制] 暂停成功');
      } else {
        await _player.play();
        _logger.info('[控制] 播放成功');
      }
    } catch (e, s) {
      _logger.severe('[控制] togglePlayPause 异常', e, s);
      state = state.copyWith(error: '操作失败: ${e.toString()}');
    }
  }

  /// 播放
  Future<void> play() async {
    _logger.info('[控制] play()');

    if (!_isInitialized) return;

    try {
      await _player.play();
      _logger.info('[控制] 播放成功');
    } catch (e, s) {
      _logger.severe('[控制] play 异常', e, s);
      state = state.copyWith(error: '播放失败: ${e.toString()}');
    }
  }

  /// 暂停
  Future<void> pause() async {
    _logger.info('[控制] pause()');

    if (!_isInitialized) return;

    try {
      await _player.pause();
      _logger.info('[控制] 暂停成功');
    } catch (e, s) {
      _logger.severe('[控制] pause 异常', e, s);
    }
  }

  /// 停止
  Future<void> stop() async {
    _logger.info('[控制] stop()');

    if (!_isInitialized) return;

    try {
      await _player.stop();
      state = state.copyWith(position: 0);
      _logger.info('[控制] 停止成功');
    } catch (e, s) {
      _logger.severe('[控制] stop 异常', e, s);
    }
  }

  /// 上一首
  Future<void> previous() async {
    _logger.fine('[控制] previous()');

    if (!_isInitialized || state.playlist.isEmpty) return;

    try {
      int prevIndex;
      if (state.isShuffle && _shuffledIndices != null) {
        final currentShufflePos = _shuffledIndices!.indexOf(state.currentIndex);
        prevIndex = _shuffledIndices![
            (currentShufflePos - 1 + _shuffledIndices!.length) %
                _shuffledIndices!.length];
      } else {
        prevIndex = (state.currentIndex - 1 + state.playlist.length) %
            state.playlist.length;
      }

      await _switchToIndex(prevIndex);
    } catch (e, s) {
      _logger.severe('[控制] previous 异常', e, s);
    }
  }

  /// 下一首
  Future<void> next() async {
    _logger.fine('[控制] next()');

    if (!_isInitialized || state.playlist.isEmpty) return;

    try {
      int nextIndex;
      if (state.isShuffle && _shuffledIndices != null) {
        final currentShufflePos = _shuffledIndices!.indexOf(state.currentIndex);
        nextIndex = _shuffledIndices![
            (currentShufflePos + 1) % _shuffledIndices!.length];
      } else {
        nextIndex = (state.currentIndex + 1) % state.playlist.length;
      }

      await _switchToIndex(nextIndex);
    } catch (e, s) {
      _logger.severe('[控制] next 异常', e, s);
    }
  }

  /// 跳转到指定位置（毫秒）
  Future<void> seekTo(int milliseconds) async {
    _logger.fine('[控制] seekTo() milliseconds=$milliseconds');

    if (!_isInitialized) return;

    try {
      await _player.seek(Duration(milliseconds: milliseconds));
    } catch (e, s) {
      _logger.severe('[控制] seekTo 异常', e, s);
    }
  }

  /// 跳转到指定百分比位置
  Future<void> seekToPercent(double percent) async {
    _logger.fine('[控制] seekToPercent() percent=$percent');

    if (!_isInitialized) return;

    try {
      final total = state.duration;
      if (total <= 0) return;
      final target = (total * percent).round();
      await seekTo(target);
    } catch (e, s) {
      _logger.severe('[控制] seekToPercent 异常', e, s);
    }
  }

  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    _logger.info('[控制] setPlayMode() mode=$mode');

    try {
      state = state.copyWith(playMode: mode);
      if (mode == PlayMode.shuffle) {
        state = state.copyWith(isShuffle: true);
        _buildShuffleIndices();
      } else {
        state = state.copyWith(isShuffle: false);
        _shuffledIndices = null;
      }
    } catch (e, s) {
      _logger.severe('[控制] setPlayMode 异常', e, s);
    }
  }

  /// 切换 shuffle 模式
  void toggleShuffle() {
    _logger.fine('[控制] toggleShuffle()');

    try {
      final newShuffle = !state.isShuffle;
      state = state.copyWith(isShuffle: newShuffle);
      if (newShuffle) {
        _buildShuffleIndices();
      } else {
        _shuffledIndices = null;
      }
    } catch (e, s) {
      _logger.severe('[控制] toggleShuffle 异常', e, s);
    }
  }

  /// 构建 shuffle 后的索引列表
  void _buildShuffleIndices() {
    try {
      final count = state.playlist.length;
      _shuffledIndices = List.generate(count, (i) => i);
      _shuffledIndices!.shuffle();

      // 确保当前歌曲在 shuffle 列表的第一个位置
      final current = state.currentIndex;
      if (current >= 0 && current < count) {
        _shuffledIndices!.remove(current);
        _shuffledIndices!.insert(0, current);
      }
    } catch (e, s) {
      _logger.severe('[控制] _buildShuffleIndices 异常', e, s);
    }
  }

  /// 循环模式切换
  void cycleRepeatMode() {
    _logger.fine('[控制] cycleRepeatMode()');

    try {
      switch (state.playMode) {
        case PlayMode.listLoop:
          state = state.copyWith(playMode: PlayMode.singleLoop);
          break;
        case PlayMode.singleLoop:
          state = state.copyWith(playMode: PlayMode.sequential);
          break;
        case PlayMode.sequential:
          state = state.copyWith(playMode: PlayMode.listLoop);
          break;
        case PlayMode.shuffle:
          state = state.copyWith(playMode: PlayMode.singleLoop);
          break;
      }
    } catch (e, s) {
      _logger.severe('[控制] cycleRepeatMode 异常', e, s);
    }
  }

  /// 歌曲播放完成时的处理
  void _onSongComplete() {
    try {
      switch (state.playMode) {
        case PlayMode.singleLoop:
          _player.seek(Duration.zero);
          _player.play();
          break;
        case PlayMode.listLoop:
          next();
          break;
        case PlayMode.shuffle:
          next();
          break;
        case PlayMode.sequential:
          if (state.currentIndex < state.playlist.length - 1) {
            next();
          } else {
            stop();
          }
          break;
      }
    } catch (e, s) {
      _logger.severe('[状态] _onSongComplete 异常', e, s);
    }
  }

  /// 设置播放队列并播放
  Future<void> setPlaylist(List<SongModel> songs, {int startIndex = 0}) async {
    _logger.info('[控制] setPlaylist() 入参: songs=${songs.length}, startIndex=$startIndex');

    try {
      state = state.copyWith(playlist: songs);

      if (songs.isEmpty) {
        _logger.warning('[控制] setPlaylist 队列为空');
        return;
      }

      // 确保 startIndex 在有效范围
      startIndex = startIndex.clamp(0, songs.length - 1);
      await _switchToIndex(startIndex, playNow: true);
    } catch (e, s) {
      _logger.severe('[控制] setPlaylist 异常', e, s);
      state = state.copyWith(error: '设置播放列表失败');
    }
  }

  /// 添加歌曲到队列末尾
  void addToPlaylist(SongModel song) {
    _logger.fine('[控制] addToPlaylist() song=${song.title}');

    try {
      state = state.copyWith(playlist: [...state.playlist, song]);
    } catch (e, s) {
      _logger.severe('[控制] addToPlaylist 异常', e, s);
    }
  }

  /// 从队列中移除歌曲
  void removeFromPlaylist(String songId) {
    _logger.fine('[控制] removeFromPlaylist() songId=$songId');

    try {
      final idx = state.playlist.indexWhere((s) => s.id == songId);
      if (idx < 0) return;

      final newPlaylist = [...state.playlist];
      newPlaylist.removeAt(idx);

      int newIndex = state.currentIndex;
      SongModel? newSong = state.currentSong;

      if (idx < state.currentIndex) {
        newIndex--;
      } else if (idx == state.currentIndex) {
        if (newPlaylist.isNotEmpty) {
          newIndex = newIndex.clamp(0, newPlaylist.length - 1);
          newSong = newPlaylist[newIndex];
        } else {
          newIndex = -1;
          newSong = null;
        }
      }

      state = state.copyWith(
        playlist: newPlaylist,
        currentIndex: newIndex,
        currentSong: newSong,
      );
    } catch (e, s) {
      _logger.severe('[控制] removeFromPlaylist 异常', e, s);
    }
  }

  /// 清空播放队列
  void clearPlaylist() {
    _logger.info('[控制] clearPlaylist()');

    try {
      stop();
      state = state.copyWith(
        playlist: [],
        currentIndex: -1,
        currentSong: null,
      );
      notifyCurrentSongChanged(null);
    } catch (e, s) {
      _logger.severe('[控制] clearPlaylist 异常', e, s);
    }
  }

  /// 测试播放 assets 中的测试音乐
  Future<void> playTestMusic() async {
    _logger.info('[测试] playTestMusic()');

    if (!_isInitialized) {
      _logger.severe('[测试] 播放器未初始化');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      _logger.fine('[测试] 加载 asset');

      await _player.setAsset('assets/test/test_music.mp3');
      _logger.info('[测试] 加载成功，开始播放');

      await _player.play();
      state = state.copyWith(isLoading: false);
    } catch (e, s) {
      _logger.severe('[测试] playTestMusic 异常', e, s);
      state = state.copyWith(
        isLoading: false,
        error: '测试播放失败: ${e.toString()}',
      );
    }
  }

  /// 释放资源
  void _dispose() {
    _logger.info('[释放] 释放播放器资源');

    try {
      if (_isInitialized) {
        _player.dispose();
        _isInitialized = false;
      }
    } catch (e, s) {
      _logger.severe('[释放] dispose 异常', e, s);
    }
  }
}

/// PlayerNotifier 的 Provider
final playerProvider = NotifierProvider<PlayerNotifier, VexfyPlayerState>(() {
  return PlayerNotifier();
});