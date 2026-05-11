import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/song_model.dart';
import 'player_service.dart';

/// 音频处理服务（AudioHandler）
/// 实现后台播放、通知栏控制、锁屏控制
/// 被 audio_service 用来在后台运行
class VexfyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final PlayerService _playerService;

  /// 当前的歌曲信息
  MediaItem? _currentMediaItem;

  /// 播放状态监听
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _currentIndexSubscription;

  VexfyAudioHandler(this._player, this._playerService) {
    // 监听 just_audio 的播放状态，转换为 audio_service 格式
    _playingSubscription = _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: _mapProcessingState(state.processingState),
      ));
    });

    // 监听播放位置
    _positionSubscription = _player.positionStream.listen((pos) {
      // 只在播放时更新位置，避免频繁回调
      if (_player.playing) {
        this.seek(pos);
      }
    });

    // 监听总时长变化
    _durationSubscription = _player.durationStream.listen((dur) {
      if (dur != null && _currentMediaItem != null) {
        // 更新 MediaItem 的时长
        final updated = _currentMediaItem!.copyWith(duration: dur);
        _currentMediaItem = updated;
        mediaItem.add(updated);
      }
    });

    // 监听当前歌曲变化
    _currentIndexSubscription =
        _playerService.currentSong.listen((song) async {
      if (song != null) {
        await _updateMediaItem(song);
      } else {
        _currentMediaItem = null;
        mediaItem.add(MediaItem(
          id: '',
          title: '未播放',
          artist: '',
          duration: Duration.zero,
        ));
      }
    });
  }

  /// 将 just_audio 的 ProcessingState 映射为 audio_service 的 AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// 构建通知栏控制按钮
  List<MediaControl> _buildControls(bool isPlaying) {
    return [
      // 上一首
      MediaControl.skipToPrevious,
      // 播放/暂停
      isPlaying ? MediaControl.pause : MediaControl.play,
      // 下一首
      MediaControl.skipToNext,
    ];
  }

  /// 更新 MediaItem（通知栏显示的歌曲信息）
  Future<void> _updateMediaItem(SongModel song) async {
    _currentMediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album ?? '',
      duration: Duration(milliseconds: song.duration),
      artUri: song.coverUrl != null ? Uri.parse(song.coverUrl!) : null,
      extras: {
        'file_path': song.filePath,
      },
    );
    mediaItem.add(_currentMediaItem!);
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(PlaybackState());
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _playerService.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await _playerService.previous();
  }

  /// 跳转到队列中的指定位置
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playerService.playlist.length) {
      final song = _playerService.playlist[index];
      await _playerService.playSong(song);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // 将 MediaItem 转换回 SongModel 并加入播放队列
    final filePath = mediaItem.extras?['file_path'] as String? ?? '';
    final song = SongModel(
      id: mediaItem.id,
      title: mediaItem.title,
      artist: mediaItem.artist,
      album: mediaItem.album,
      duration: mediaItem.duration.inMilliseconds,
      coverUrl: mediaItem.artUri?.toString(),
      source: SongSource.local,
      filePath: filePath,
    );
    _playerService.addToPlaylist(song);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _playerService.removeFromPlaylist(mediaItem.id);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    // 将 MediaItem 列表转换回 SongModel 列表
    final songs = queue.map((item) {
      final filePath = item.extras?['file_path'] as String? ?? '';
      return SongModel(
        id: item.id,
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration: item.duration.inMilliseconds,
        coverUrl: item.artUri?.toString(),
        source: SongSource.local,
        filePath: filePath,
      );
    }).toList();

    await _playerService.setPlaylist(songs);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    // 通知 PlayerService 更新 shuffle 模式
    if (mode == AudioServiceShuffleMode.all) {
      _playerService.toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    // 通知 PlayerService 更新重复模式
    switch (mode) {
      case AudioServiceRepeatMode.none:
        _playerService.playMode.value = PlayMode.sequential;
        break;
      case AudioServiceRepeatMode.one:
        _playerService.playMode.value = PlayMode.singleLoop;
        break;
      case AudioServiceRepeatMode.all:
        _playerService.playMode.value = PlayMode.listLoop;
        break;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
  }

  /// 释放资源
  void dispose() {
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentIndexSubscription?.cancel();
  }
}

/// 启动音频服务（后台播放）
/// 返回 AudioHandler 实例，供 PlayerService 使用
Future<VexfyAudioHandler> startAudioService() async {
  return await AudioService.init(
    builder: () {
      // 获取 PlayerService 实例
      final playerService = PlayerService.instance;

      // 创建 AudioHandler，通过公开的 getter 访问 _player
      return VexfyAudioHandler(
        playerService.player,
        playerService,
      );
    },
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vexfy.vexfy.audio',
      androidNotificationChannelName: 'Vexfy 音乐播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: 0xFF1DB954, // Vexfy 主题绿色
    ),
  );
}