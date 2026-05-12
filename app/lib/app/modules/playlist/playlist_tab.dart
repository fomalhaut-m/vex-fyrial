import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/local_music_provider.dart';
import '../../../data/models/song_model.dart';

/// Tab 2：播放列表页面
/// 显示本地音乐列表，支持搜索、筛选
class PlaylistTab extends ConsumerStatefulWidget {
  const PlaylistTab({super.key});

  @override
  ConsumerState<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends ConsumerState<PlaylistTab>
    with SingleTickerProviderStateMixin {
  /// Tab 控制器
  late final TabController _tabController;

  /// 搜索关键词
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

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

    // 初始加载歌曲
    Future.microtask(() {
      ref.read(localMusicProvider.notifier).loadAllSongs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 扫描本地音乐
  Future<void> _scanMusic() async {
    final notifier = ref.read(localMusicProvider.notifier);
    if (notifier.state.isScanning) return;

    try {
      final count = await notifier.scanAllMusic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('共扫描到 $count 首歌曲'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 播放歌曲
  void _playSong(SongModel song, List<SongModel> allSongs) {
    final startIndex = allSongs.indexOf(song);
    ref.read(playerProvider.notifier).setPlaylist(allSongs, startIndex: startIndex);
  }

  @override
  Widget build(BuildContext context) {
    final localMusicState = ref.watch(localMusicProvider);
    final songs = localMusicState.songs;
    final isScanning = localMusicState.isScanning;
    final scanProgress = localMusicState.scanProgress;
    final scanTotal = localMusicState.scanTotal;

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
          isScanning
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
                ),
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
          _buildStatsBar(songs),

          // 歌曲列表
          Expanded(
            child: _buildBody(songs, isScanning, scanProgress, scanTotal),
          ),
        ],
      ),
    );
  }

  /// 统计栏
  Widget _buildStatsBar(List<SongModel> songs) {
    final count = songs.length;
    final totalMs = songs.fold<int>(0, (sum, s) => sum + s.duration);
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Text(
        '共 $count 首  ·  总时长 ${hours > 0 ? "${hours}小时" : ""}$minutes分钟',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFB3B3B3),
        ),
      ),
    );
  }

  /// 主体内容
  Widget _buildBody(
    List<SongModel> songs,
    bool isScanning,
    int scanProgress,
    int scanTotal,
  ) {
    // 扫描进度显示
    if (isScanning && scanTotal > 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1DB954),
            ),
            const SizedBox(height: 16),
            Text(
              '已扫描 $scanProgress / $scanTotal 首',
              style: const TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ],
        ),
      );
    }

    // 过滤歌曲
    final filtered = _filterSongs(songs);

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final song = filtered[index];
        return _buildSongTile(song, songs);
      },
    );
  }

  /// 过滤歌曲
  List<SongModel> _filterSongs(List<SongModel> songs) {
    if (_searchKeyword.isEmpty) return songs;

    final keyword = _searchKeyword.toLowerCase();
    return songs.where((song) {
      return song.title.toLowerCase().contains(keyword) ||
          song.artist.toLowerCase().contains(keyword);
    }).toList();
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
  Widget _buildSongTile(SongModel song, List<SongModel> allSongs) {
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
      onTap: () => _playSong(song, allSongs),
    );
  }
}