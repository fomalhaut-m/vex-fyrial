import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/song_model.dart';

/// 播放模式枚举
enum PlayMode {
  /// 列表循环：播完最后一首回到第一首
  listLoop,
  /// 单曲循环：循环播放当前歌曲
  singleLoop,
  /// 随机播放：随机切换歌曲
  shuffle,
  /// 顺序播放：播完停止
  sequential,
}

/// 播放器服务 - 全局单例
/// 封装 just_audio，提供播放控制、队列管理、进度监听
/// 组合 AudioHandler 实现后台播放 + 通知栏控制
class PlayerService extends GetxService {
  // 单例模式
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  /// just_audio 的 AudioPlayer 实例
  /// 公开给 AudioHandler 访问
  late final AudioPlayer _player;

  /// 对外暴露 player 实例（供 AudioHandler 访问）
  AudioPlayer get player => _player;

  /// 播放队列
  final RxList<SongModel> playlist = <SongModel>[].obs;

  /// 当前播放索引
  final RxInt currentIndex = (-1).obs;

  /// 当前播放歌曲
  final Rx<SongModel?> currentSong = Rx<SongModel?>(null);

  /// 播放状态：是否正在播放
  final RxBool isPlaying = false.obs;

  /// 播放状态：是否正在加载
  final RxBool isLoading = false.obs;

  /// 当前播放位置（毫秒）
  final RxInt position = 0.obs;

  /// 当前歌曲总时长（毫秒）
  final RxInt duration = 0.obs;

  /// 播放模式
  final Rx<PlayMode> playMode = PlayMode.listLoop.obs;

  /// 随机模式是否开启
  final RxBool isShuffle = false.obs;

  /// 内部队列（用于 shuffle 模式打乱顺序）
  List<int>? _shuffledIndices;

  /// GetX onInit
  @override
  void onInit() {
    super.onInit();
    _initPlayer();
  }

  /// 初始化播放器
  Future<void> _initPlayer() async {
    _player = AudioPlayer();

    // 监听播放状态变化
    _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      isLoading.value = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // 播放结束时自动切到下一首
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
    });

    // 监听播放位置变化
    _player.positionStream.listen((pos) {
      position.value = pos.inMilliseconds;
    });

    // 监听总时长
    _player.durationStream.listen((dur) {
      if (dur != null) {
        duration.value = dur.inMilliseconds;
      }
    });
  }

  /// 播放指定歌曲
  /// [song] 要播放的歌曲
  /// [playNow] 是否立即播放，false 则只加入队列
  Future<void> playSong(SongModel song, {bool playNow = true}) async {
    // 如果歌曲不在队列中，先加入队列
    int idx = playlist.indexWhere((s) => s.id == song.id);
    if (idx < 0) {
      playlist.add(song);
      idx = playlist.length - 1;
    }

    // 切换到该歌曲
    await _switchToIndex(idx, playNow: playNow);
  }

  /// 切换到指定索引的歌曲
  Future<void> _switchToIndex(int index, {bool playNow = true}) async {
    if (index < 0 || index >= playlist.length) return;

    currentIndex.value = index;
    currentSong.value = playlist[index];

    // 加载音频源
    final song = playlist[index];
    final filePath = song.filePath;
    if (filePath == null) return;

    isLoading.value = true;
    try {
      await _player.setFilePath(filePath);
      if (playNow) {
        await _player.play();
      }
    } catch (e) {
      isLoading.value = false;
      rethrow;
    }
  }

  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// 播放
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
    position.value = 0;
  }

  /// 上一首
  Future<void> previous() async {
    if (playlist.isEmpty) return;

    int prevIndex;
    if (isShuffle.value && _shuffledIndices != null) {
      // shuffle 模式：在 shuffledIndices 里找上一个
      final currentShufflePos = _shuffledIndices!.indexOf(currentIndex.value);
      prevIndex = _shuffledIndices![
          (currentShufflePos - 1 + _shuffledIndices!.length) %
              _shuffledIndices!.length];
    } else {
      prevIndex = (currentIndex.value - 1 + playlist.length) % playlist.length;
    }

    await _switchToIndex(prevIndex);
  }

  /// 下一首
  Future<void> next() async {
    if (playlist.isEmpty) return;

    int nextIndex;
    if (isShuffle.value && _shuffledIndices != null) {
      // shuffle 模式
      final currentShufflePos = _shuffledIndices!.indexOf(currentIndex.value);
      nextIndex = _shuffledIndices![
          (currentShufflePos + 1) % _shuffledIndices!.length];
    } else {
      nextIndex = (currentIndex.value + 1) % playlist.length;
    }

    await _switchToIndex(nextIndex);
  }

  /// 跳转到指定位置
  /// [milliseconds] 目标位置，毫秒
  Future<void> seekTo(int milliseconds) async {
    await _player.seek(Duration(milliseconds: milliseconds));
  }

  /// 跳转到指定百分比位置
  /// [percent] 0.0 ~ 1.0
  Future<void> seekToPercent(double percent) async {
    final total = duration.value;
    if (total <= 0) return;
    final target = (total * percent).round();
    await seekTo(target);
  }

  /// 播放进度百分比（0.0 ~ 1.0）
  double get progressPercent {
    if (duration.value == 0) return 0;
    return position.value / duration.value;
  }

  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    playMode.value = mode;
    if (mode == PlayMode.shuffle) {
      isShuffle.value = true;
      _buildShuffleIndices();
    } else {
      isShuffle.value = false;
      _shuffledIndices = null;
    }
  }

  /// 切换 shuffle 模式
  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    if (isShuffle.value) {
      _buildShuffleIndices();
    } else {
      _shuffledIndices = null;
    }
  }

  /// 构建 shuffle 后的索引列表
  void _buildShuffleIndices() {
    final count = playlist.length;
    _shuffledIndices = List.generate(count, (i) => i);
    _shuffledIndices!.shuffle();

    // 确保当前歌曲在 shuffle 列表的第一个位置
    final current = currentIndex.value;
    if (current >= 0 && current < count) {
      _shuffledIndices!.remove(current);
      _shuffledIndices!.insert(0, current);
    }
  }

  /// 循环模式切换（列表循环 → 单曲循环 → 关闭 → 列表循环）
  void cycleRepeatMode() {
    switch (playMode.value) {
      case PlayMode.listLoop:
        playMode.value = PlayMode.singleLoop;
        break;
      case PlayMode.singleLoop:
        playMode.value = PlayMode.sequential;
        break;
      case PlayMode.sequential:
        playMode.value = PlayMode.listLoop;
        break;
      case PlayMode.shuffle:
        // shuffle 模式下 cycle 是单曲循环
        playMode.value = PlayMode.singleLoop;
        break;
    }
  }

  /// 歌曲播放完成时的处理
  void _onSongComplete() {
    switch (playMode.value) {
      case PlayMode.singleLoop:
        // 单曲循环：重新播放当前歌曲
        _player.seek(Duration.zero);
        _player.play();
        break;
      case PlayMode.listLoop:
        // 列表循环：下一首
        next();
        break;
      case PlayMode.shuffle:
        // shuffle 模式：下一首
        next();
        break;
      case PlayMode.sequential:
        // 顺序播放：如果不是最后一首就下一首，否则停止
        if (currentIndex.value < playlist.length - 1) {
          next();
        } else {
          stop();
        }
        break;
    }
  }

  /// 设置播放队列并播放
  Future<void> setPlaylist(List<SongModel> songs, {int startIndex = 0}) async {
    playlist.clear();
    playlist.addAll(songs);

    if (songs.isEmpty) return;

    // 确保 startIndex 在有效范围
    startIndex = startIndex.clamp(0, songs.length - 1);
    await _switchToIndex(startIndex, playNow: true);
  }

  /// 添加歌曲到队列末尾
  void addToPlaylist(SongModel song) {
    playlist.add(song);
  }

  /// 从队列中移除歌曲
  void removeFromPlaylist(String songId) {
    final idx = playlist.indexWhere((s) => s.id == songId);
    if (idx < 0) return;

    playlist.removeAt(idx);

    // 如果移除的是当前歌曲之前的歌曲，当前索引 -1
    if (idx < currentIndex.value) {
      currentIndex.value--;
    } else if (idx == currentIndex.value) {
      // 移除的是当前歌曲，切换到下一首或上一首
      if (playlist.isNotEmpty) {
        final newIndex = currentIndex.value.clamp(0, playlist.length - 1);
        _switchToIndex(newIndex, playNow: isPlaying.value);
      } else {
        currentIndex.value = -1;
        currentSong.value = null;
      }
    }
  }

  /// 清空播放队列
  void clearPlaylist() {
    stop();
    playlist.clear();
    currentIndex.value = -1;
    currentSong.value = null;
  }

  /// 格式化时长（毫秒 → "3:45"）
  String formatDuration(int milliseconds) {
    final d = Duration(milliseconds: milliseconds);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 当前已播放时间字符串
  String get currentTimeString => formatDuration(position.value);

  /// 总时长字符串
  String get totalTimeString => formatDuration(duration.value);

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}