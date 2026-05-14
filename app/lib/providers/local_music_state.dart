import '../models/song_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
///
///   📀 本地音乐状态数据模型
///   Local Music State Data Model
///
///   用于存储本地音乐扫描和管理的所有状态信息
///   Stores all state information for local music scanning and management
///
/// ═══════════════════════════════════════════════════════════════════════════
class LocalMusicState {
  /// 🎵 歌曲列表
  /// 当前已扫描的所有本地歌曲
  final List<SongModel> songs;

  /// 🔄 扫描状态标志
  /// true: 正在扫描中
  /// false: 扫描已完成或未开始
  final bool isScanning;

  /// 📊 当前扫描进度
  /// 已完成扫描的文件数量
  final int scanProgress;

  /// 📊 扫描总数
  /// 预计需要扫描的总数（部分实现中可能不准确）
  final int scanTotal;

  /// ❌ 错误信息
  /// 当发生错误时存储错误描述
  final String? error;

  /// 📁 已选择的扫描目录列表
  /// 用户选择用于扫描音乐文件的目录
  final List<String> scanDirectories;

  /// 🔐 存储权限状态
  /// true: 已获得存储权限
  /// false: 未获得存储权限
  final bool hasPermission;

  const LocalMusicState({
    this.songs = const [],
    this.isScanning = false,
    this.scanProgress = 0,
    this.scanTotal = 0,
    this.error,
    this.scanDirectories = const [],
    this.hasPermission = false,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  ///
  ///   🔧 状态复制方法
  ///   State Copy Method
  ///
  ///   创建一个新的状态实例，可选择性覆盖部分字段
  ///   Creates a new state instance with optional field overrides
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  LocalMusicState copyWith({
    List<SongModel>? songs,
    bool? isScanning,
    int? scanProgress,
    int? scanTotal,
    String? error,
    List<String>? scanDirectories,
    bool? hasPermission,
  }) {
    return LocalMusicState(
      songs: songs ?? this.songs,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      scanTotal: scanTotal ?? this.scanTotal,
      error: error,
      scanDirectories: scanDirectories ?? this.scanDirectories,
      hasPermission: hasPermission ?? this.hasPermission,
    );
  }
}