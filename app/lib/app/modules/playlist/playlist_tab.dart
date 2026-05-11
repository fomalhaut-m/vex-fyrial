import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/player_service.dart';
import '../../../services/local_music_service.dart';
import '../../../data/models/song_model.dart';

/// Tab 2：播放列表页面
/// 显示本地音乐列表，支持搜索、筛选
class PlaylistTab extends StatefulWidget {
  const PlaylistTab({super.key});

  @override
  State<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends State<PlaylistTab>
    with SingleTickerProviderStateMixin {
  /// Tab 控制器
  late final TabController _tabController;

  /// 本地音乐服务
  final LocalMusicService _localMusicService = LocalMusicService.instance;

  /// 播放器服务
  PlayerService get _playerService => Get.find<PlayerService>();

  /// 歌曲列表
  final RxList<SongModel> _songs = <SongModel>[].obs;

  /// 是否正在扫描
  final RxBool _isScanning = false.obs;

  /// 扫描进度
  final RxInt _scanProgress = 0.obs;
  final RxInt _scanTotal = 0.obs;

  /// 搜索关键词
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchKeyword = ''.obs;

  /// 当前子 Tab 索引
  int _subTabIndex = 0; // 0=全部 1=最近播放 2=收藏

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _subTabIndex = _tabController.index;
      });
    });
    _loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 加载本地歌曲列表
  Future<void> _loadSongs() async {
    final loaded = await _localMusicService.loadAllSongs();
    _songs.assignAll(loaded);
  }

  /// 扫描本地音乐
  Future<void> _scanMusic() async {
    if (_isScanning.value) return;

    _isScanning.value = true;
    _scanProgress.value = 0;
    _scanTotal.value = 0;

    try {
      final count = await _localMusicService.scanAllMusic(
        onProgress: (scanned, total) {
          _scanProgress.value = scanned;
          _scanTotal.value = total;
        },
      );

      // 重新加载歌曲列表
      await _loadSongs();

      Get.snackbar(
        '扫描完成',
        '共扫描到 $count 首歌曲',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '扫描失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isScanning.value = false;
    }
  }

  /// 播放歌曲
  void _playSong(SongModel song) {
    // 设置播放队列并播放
    _playerService.setPlaylist(_songs.toList(), startIndex: _songs.indexOf(song));
  }

  /// 搜索歌曲
  List<SongModel> _filterSongs() {
    final keyword = _searchKeyword.value.toLowerCase();
    if (keyword.isEmpty) return _songs.toList();

    return _songs.where((song) {
      return song.title.toLowerCase().contains(keyword) ||
          song.artist.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 页面标题
      appBar: AppBar(
        title: const Text('播放列表'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 展开搜索框
            },
          ),

          // 扫描按钮
          Obx(() => _isScanning.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _scanMusic,
                )),
        ],

        // 子 Tab 筛选
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '最近播放'),
            Tab(text: '收藏'),
          ],
          indicatorColor: const Color(0xFF1DB954),
          labelColor: const Color(0xFF1DB954),
          unselectedLabelColor: const Color(0xFFB3B3B3),
        ),
      ),

      body: Column(
        children: [
          // 统计栏：歌曲数量 + 总时长
          _buildStatsBar(),

          // 歌曲列表
          Expanded(
            child: Obx(() {
              // 扫描进度显示
              if (_isScanning.value && _scanTotal.value > 0) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF1DB954),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '已扫描 ${_scanProgress.value} / ${_scanTotal.value} 首',
                        style: const TextStyle(color: Color(0xFFB3B3B3)),
                      ),
                    ],
                  ),
                );
              }

              // 歌曲列表
              final filtered = _filterSongs();

              if (filtered.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final song = filtered[index];
                  return _buildSongTile(song);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 统计栏
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Obx(() {
        final count = _songs.length;
        final totalMs = _songs.fold<int>(0, (sum, s) => sum + s.duration);
        final hours = totalMs ~/ 3600000;
        final minutes = (totalMs % 3600000) ~/ 60000;

        return Text(
          '共 $count 首  ·  总时长 ${hours > 0 ? "${hours}小时" : ""}$minutes分钟',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFB3B3B3),
          ),
        );
      }),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_off,
            size: 64,
            color: Color(0xFFB3B3B3),
          ),
          const SizedBox(height: 16),
          const Text(
            '未发现本地音乐',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右上角扫描本地音乐',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB3B3B3),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanMusic,
            icon: const Icon(Icons.refresh),
            label: const Text('扫描本地音乐'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 歌曲列表项
  Widget _buildSongTile(SongModel song) {
    return ListTile(
      // 左侧音乐图标
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: song.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  song.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.music_note, color: Colors.grey),
                ),
              )
            : const Icon(Icons.music_note, color: Colors.grey),
      ),

      // 中间：歌名 + 歌手
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFB3B3B3),
        ),
      ),

      // 右侧：时长
      trailing: Text(
        song.displayDuration,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFB3B3B3),
        ),
      ),

      // 点击播放
      onTap: () => _playSong(song),
    );
  }
}