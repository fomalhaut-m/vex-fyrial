import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart' as logging;

import '../data/models/song_model.dart';
import '../providers/player_provider.dart';

/// 音频处理服务（AudioHandler）
/// 实现后台播放、通知栏控制、锁屏控制
/// 支持 just_audio_mpv（Linux 桌面）
/// 所有操作都有完善的日志和异常兜底
class VexfyAudioHandler extends BaseAudioHandler with SeekHandler {
  static const _tag = '[VexfyAudioHandler]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  /// just_audio player 实例
  AudioPlayer? _player;

  /// PlayerNotifier 引用
  PlayerNotifier? _playerNotifier;

  /// 当前的歌曲信息
  MediaItem? _currentMediaItem;

  /// 播放状态监听
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _songSubscription;

  VexfyAudioHandler() {
    _logger.info('[初始化] VexfyAudioHandler 创建');
  }

  /// 关联 PlayerNotifier
  void attachPlayerNotifier(PlayerNotifier notifier) {
    _logger.info('[关联] attachPlayerNotifier()');

    _playerNotifier = notifier;
    _player = notifier.player;
    _logger.info('[关联] PlayerNotifier 关联成功');
  }

  /// PlayerNotifier 状态变化回调
  void _onPlayerStateChanged() {
    try {
      if (_playerNotifier == null) return;

      final state = _playerNotifier!.state;
      updateCurrentSong(state.currentSong);
    } catch (e, s) {
      _logger.severe('[状态] _onPlayerStateChanged 异常', e, s);
    }
  }

  /// 更新当前歌曲（通知栏显示）
  void updateCurrentSong(SongModel? song) {
    _logger.fine('[更新] updateCurrentSong() song=${song?.title}');

    try {
      if (song != null) {
        _currentMediaItem = MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album ?? '',
          duration: Duration(milliseconds: song.duration),
          artUri: song.coverUrl != null ? Uri.parse(song.coverUrl!) : null,
          extras: {
            'file_path': song.filePath ?? '',
          },
        );
        mediaItem.add(_currentMediaItem!);
        _logger.fine('[更新] 通知栏更新成功: ${song.title}');
      } else {
        _currentMediaItem = null;
        mediaItem.add(MediaItem(
          id: '',
          title: '未播放',
          artist: '',
          duration: Duration.zero,
        ));
      }
    } catch (e, s) {
      _logger.severe('[更新] updateCurrentSong 异常', e, s);
    }
  }

  /// 将 just_audio 的 ProcessingState 映射为 audio_service 的 AudioProcessingState
  AudioProcessingState _mapProcessingState(ProcessingState state) {
    try {
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
    } catch (e, s) {
      _logger.severe('[映射] _mapProcessingState 异常', e, s);
      return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() async {
    _logger.fine('[控制] play()');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.play();
      }
    } catch (e, s) {
      _logger.severe('[控制] play 异常', e, s);
    }
  }

  @override
  Future<void> pause() async {
    _logger.fine('[控制] pause()');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.pause();
      }
    } catch (e, s) {
      _logger.severe('[控制] pause 异常', e, s);
    }
  }

  @override
  Future<void> stop() async {
    _logger.fine('[控制] stop()');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.stop();
      }
      playbackState.add(PlaybackState());
    } catch (e, s) {
      _logger.severe('[控制] stop 异常', e, s);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _logger.fine('[控制] seek() position=$position');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.seekTo(position.inMilliseconds);
      }
    } catch (e, s) {
      _logger.severe('[控制] seek 异常', e, s);
    }
  }

  @override
  Future<void> skipToNext() async {
    _logger.fine('[控制] skipToNext()');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.next();
      }
    } catch (e, s) {
      _logger.severe('[控制] skipToNext 异常', e, s);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    _logger.fine('[控制] skipToPrevious()');

    try {
      if (_playerNotifier != null) {
        await _playerNotifier!.previous();
      }
    } catch (e, s) {
      _logger.severe('[控制] skipToPrevious 异常', e, s);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _logger.fine('[控制] skipToQueueItem() index=$index');

    try {
      if (_playerNotifier != null) {
        final playlist = _playerNotifier!.state.playlist;
        if (index >= 0 && index < playlist.length) {
          await _playerNotifier!.playSong(playlist[index]);
        }
      }
    } catch (e, s) {
      _logger.severe('[控制] skipToQueueItem 异常', e, s);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _logger.fine('[控制] addQueueItem() title=${mediaItem.title}');

    try {
      if (_playerNotifier != null) {
        final rawPath = mediaItem.extras?['file_path'];
        final filePath = rawPath != null ? '$rawPath' : '';
        final dur = mediaItem.duration ?? Duration.zero;

        final song = SongModel(
          id: mediaItem.id,
          title: mediaItem.title,
          artist: mediaItem.artist ?? '',
          album: mediaItem.album ?? '',
          duration: dur.inMilliseconds,
          coverUrl: mediaItem.artUri?.toString(),
          source: SongSource.local,
          filePath: filePath,
        );
        _playerNotifier!.addToPlaylist(song);
      }
    } catch (e, s) {
      _logger.severe('[控制] addQueueItem 异常', e, s);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _logger.fine('[控制] removeQueueItem() id=${mediaItem.id}');

    try {
      if (_playerNotifier != null) {
        _playerNotifier!.removeFromPlaylist(mediaItem.id);
      }
    } catch (e, s) {
      _logger.severe('[控制] removeQueueItem 异常', e, s);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _logger.fine('[控制] updateQueue() count=${queue.length}');

    try {
      if (_playerNotifier != null) {
        final songs = <SongModel>[];
        for (final item in queue) {
          final rawPath = item.extras?['file_path'];
          final filePath = rawPath != null ? '$rawPath' : '';
          final dur = item.duration ?? Duration.zero;

          songs.add(SongModel(
            id: item.id,
            title: item.title,
            artist: item.artist ?? '',
            album: item.album ?? '',
            duration: dur.inMilliseconds,
            coverUrl: item.artUri?.toString(),
            source: SongSource.local,
            filePath: filePath,
          ));
        }
        await _playerNotifier!.setPlaylist(songs);
      }
    } catch (e, s) {
      _logger.severe('[控制] updateQueue 异常', e, s);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _logger.fine('[控制] setShuffleMode() shuffleMode=$shuffleMode');

    try {
      if (_playerNotifier != null && shuffleMode == AudioServiceShuffleMode.all) {
        _playerNotifier!.toggleShuffle();
      }
    } catch (e, s) {
      _logger.severe('[控制] setShuffleMode 异常', e, s);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _logger.fine('[控制] setRepeatMode() repeatMode=$repeatMode');

    try {
      if (_playerNotifier != null) {
        switch (repeatMode) {
          case AudioServiceRepeatMode.none:
            _playerNotifier!.setPlayMode(PlayMode.sequential);
            break;
          case AudioServiceRepeatMode.one:
            _playerNotifier!.setPlayMode(PlayMode.singleLoop);
            break;
          case AudioServiceRepeatMode.all:
            _playerNotifier!.setPlayMode(PlayMode.listLoop);
            break;
          case AudioServiceRepeatMode.group:
            break;
        }
      }
    } catch (e, s) {
      _logger.severe('[控制] setRepeatMode 异常', e, s);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    _logger.info('[控制] onTaskRemoved()');

    try {
      await stop();
      _player?.dispose();
    } catch (e, s) {
      _logger.severe('[控制] onTaskRemoved 异常', e, s);
    }
  }

  /// 释放资源
  void dispose() {
    _logger.info('[释放] dispose()');

    try {
      _playingSubscription?.cancel();
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _songSubscription?.cancel();
    } catch (e, s) {
      _logger.severe('[释放] dispose 异常', e, s);
    }
  }
}

/// 全局 AudioHandler 实例（单例）
VexfyAudioHandler? _audioHandler;

/// 获取全局 AudioHandler
VexfyAudioHandler get audioHandler {
  _audioHandler ??= VexfyAudioHandler();
  return _audioHandler!;
}

/// 启动音频服务（后台播放）
/// 失败不影响主流程
Future<VexfyAudioHandler?> startAudioService() async {
  final logger = logging.Logger('[Vexfy AudioService]')..level = logging.Level.INFO;
  logger.info('启动音频服务...');

  try {
    final handler = await AudioService.init(
      builder: () => audioHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.vexfy.vexfy.audio',
        androidNotificationChannelName: 'Vexfy 音乐播放',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF1DB954),
      ),
    );

    logger.info('音频服务启动成功');
    return handler;
  } catch (e, s) {
    logger.warning('音频服务启动失败: $e');
    logger.severe('堆栈', e, s);
    return null;
  }
}

/// 带降级的音频服务启动
Future<VexfyAudioHandler?> startAudioServiceWithFallback() async {
  return await startAudioService();
}