import 'package:json_annotation/json_annotation.dart';

part 'playlist_model.g.dart';

/// 歌单数据模型
@JsonSerializable()
class PlaylistModel {
  final String id;
  final String name;
  final String? coverUrl;
  final String? description;
  final String creator;
  final String type; // userCreated / favorite / history
  final List<String> songIds; // 歌曲ID列表
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaylistModel({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    required this.creator,
    required this.type,
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
  });
}
