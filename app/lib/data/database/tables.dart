/// 数据库表名常量定义
/// 统一管理所有表名，避免硬编码字符串
class Tables {
  Tables._();

  /// 歌单表
  static const String playlists = 'playlists';

  /// 歌单歌曲关联表
  static const String playlistSongs = 'playlist_songs';

  /// 歌曲播放统计表
  static const String songStats = 'song_stats';

  /// 歌曲表（本地音乐索引）
  static const String songs = 'songs';

  /// 播放历史表
  static const String playedHistory = 'played_history';

  /// 本地音乐元数据表
  static const String localFileMetadata = 'local_file_metadata';

  /// OSS 同步队列表
  static const String syncQueue = 'sync_queue';

  /// 应用信息表（存储版本号等）
  static const String appInfo = 'app_info';
}