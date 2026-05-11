import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/player_service.dart';

/// Tab 3：统计页面
/// 显示播放统计（播放次数/时长/分类/时段）
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放统计'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总统计卡片
            _buildSummaryCard(),

            const SizedBox(height: 24),

            // 时间维度 Tab
            _buildTimeRangeTabs(),

            const SizedBox(height: 24),

            // 时段分布
            _buildTimeSlotSection(),

            const SizedBox(height: 24),

            // 提示文字
            _buildEmptyHint(),
          ],
        ),
      ),
    );
  }

  /// 总统计卡片
  Widget _buildSummaryCard() {
    // TODO: 接入 PlayStatsService 获取真实数据
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1DB954).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('0', '总播放时长'),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          _buildStatItem('0', '总播放次数'),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          _buildStatItem('0', '歌曲数量'),
        ],
      ),
    );
  }

  /// 单个统计项
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1DB954),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB3B3B3),
          ),
        ),
      ],
    );
  }

  /// 时间维度 Tab（按日/按周/按月）
  Widget _buildTimeRangeTabs() {
    return Row(
      children: [
        _buildTimeTab('按日', true),
        const SizedBox(width: 8),
        _buildTimeTab('按周', false),
        const SizedBox(width: 8),
        _buildTimeTab('按月', false),
      ],
    );
  }

  Widget _buildTimeTab(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1DB954) : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey[600],
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  /// 时段分布
  Widget _buildTimeSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '时段分布',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // 时段条目
        _buildTimeSlotItem('🌅', '上午', '0次', '0%', 0),
        const SizedBox(height: 12),
        _buildTimeSlotItem('☀️', '下午', '0次', '0%', 0),
        const SizedBox(height: 12),
        _buildTimeSlotItem('🌆', '傍晚', '0次', '0%', 0),
        const SizedBox(height: 12),
        _buildTimeSlotItem('🌙', '深夜', '0次', '0%', 0),
      ],
    );
  }

  /// 时段条目
  Widget _buildTimeSlotItem(
      String emoji, String label, String count, String percent, double ratio) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF1DB954),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              percent,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB3B3B3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 空数据提示
  Widget _buildEmptyHint() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB3B3B3)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '开始播放音乐，统计数据将在这里显示',
              style: TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ),
        ],
      ),
    );
  }
}