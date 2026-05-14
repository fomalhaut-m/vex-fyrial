import 'package:json_annotation/json_annotation.dart';

part 'song_stats_model.g.dart';

/// 歌曲播放统计模型
@JsonSerializable()
class SongStatsModel {
  final String songId;
  final int playCount;
  final int totalSeconds;
  @JsonKey(name: 'last_played_at')
  final DateTime? lastPlayedAt;
  @JsonKey(name: 'favorite_segment_start')
  final int? favoriteSegmentStart; // 最爱片段开始时间（秒）
  @JsonKey(name: 'favorite_segment_count')
  final int favoriteSegmentCount;
  @JsonKey(name: 'favorite_time_slot')
  final String? favoriteTimeSlot; // morning/afternoon/evening/night
  @JsonKey(name: 'morning_count')
  final int morningCount; // 6:00-12:00
  @JsonKey(name: 'afternoon_count')
  final int afternoonCount; // 12:00-18:00
  @JsonKey(name: 'evening_count')
  final int eveningCount; // 18:00-24:00
  @JsonKey(name: 'night_count')
  final int nightCount; // 0:00-6:00
  final DateTime createdAt;
  final DateTime updatedAt;

  SongStatsModel({
    required this.songId,
    this.playCount = 0,
    this.totalSeconds = 0,
    this.lastPlayedAt,
    this.favoriteSegmentStart,
    this.favoriteSegmentCount = 0,
    this.favoriteTimeSlot,
    this.morningCount = 0,
    this.afternoonCount = 0,
    this.eveningCount = 0,
    this.nightCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

}
