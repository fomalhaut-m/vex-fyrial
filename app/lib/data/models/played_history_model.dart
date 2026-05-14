import 'package:json_annotation/json_annotation.dart';

part 'played_history_model.g.dart';

/// 播放历史记录模型
@JsonSerializable()
class PlayedHistoryModel {
  final String id; // 使用时间戳作为ID
  @JsonKey(name: 'song_id')
  final String songId;
  final String title;
  final String artist;
  final int? duration; // 毫秒
  @JsonKey(name: 'file_path')
  final String? filePath;
  @JsonKey(name: 'played_at')
  final DateTime playedAt;

  PlayedHistoryModel({
    required this.id,
    required this.songId,
    required this.title,
    required this.artist,
    this.duration,
    this.filePath,
    required this.playedAt,
  });

  /// 从 JSON 创建实例（自动生成）
  factory PlayedHistoryModel.fromJson(Map<String, dynamic> json) =>
      _$PlayedHistoryModelFromJson(json);

  /// 转换为 JSON（自动生成）
  Map<String, dynamic> toJson() => _$PlayedHistoryModelToJson(this);
}
