import 'package:json_annotation/json_annotation.dart';

part 'song_model.g.dart';

/// 歌曲来源枚举
enum SongSource {
  local,
  online;

  String toJson() => name;
  
  static SongSource fromJson(String value) => SongSource.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SongSource.local,
  );
}

/// 歌曲模型 - 核心实体，通用本地和在线歌曲
@JsonSerializable()
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

}
