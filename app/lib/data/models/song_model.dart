/// 歌曲来源枚举
/// [local] 本地音乐，[online] 在线音乐
enum SongSource { local, online }

/// 歌曲模型 - 核心实体，通用本地和在线歌曲
class SongModel {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int duration; // 毫秒
  final String? coverUrl;
  final SongSource source;
  final String? filePath; // 本地歌曲才有
  final String? onlineUrl; // 在线歌曲才有
  final String? lyrics;
  final bool isFavorite;
  final int playCount;
  final int? fileSize;
  final String? mimeType;
  final DateTime? createdAt;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.duration,
    this.coverUrl,
    required this.source,
    this.filePath,
    this.onlineUrl,
    this.lyrics,
    this.isFavorite = false,
    this.playCount = 0,
    this.fileSize,
    this.mimeType,
    this.createdAt,
  });

  /// 格式化时长显示，如 "4:35"
  String get displayDuration {
    final d = Duration(milliseconds: duration);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 是否是本地歌曲
  bool get isLocal => source == SongSource.local;

  /// 复制并修改某些字段
  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? coverUrl,
    SongSource? source,
    String? filePath,
    String? onlineUrl,
    String? lyrics,
    bool? isFavorite,
    int? playCount,
    int? fileSize,
    String? mimeType,
    DateTime? createdAt,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
      onlineUrl: onlineUrl ?? this.onlineUrl,
      lyrics: lyrics ?? this.lyrics,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 从 Map（数据库行）构造
  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String?,
      duration: map['duration'] as int? ?? 0,
      coverUrl: map['cover_url'] as String?,
      source: map['source'] == 'online' ? SongSource.online : SongSource.local,
      filePath: map['file_path'] as String?,
      onlineUrl: map['online_url'] as String?,
      lyrics: map['lyrics'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      playCount: map['play_count'] as int? ?? 0,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  /// 转为 Map（存入数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'cover_url': coverUrl,
      'source': source == SongSource.online ? 'online' : 'local',
      'file_path': filePath,
      'online_url': onlineUrl,
      'lyrics': lyrics,
      'is_favorite': isFavorite ? 1 : 0,
      'play_count': playCount,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}