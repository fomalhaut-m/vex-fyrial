import 'package:flutter/material.dart';

/// Tab 4：设置页面
/// 显示 OSS 配置、音质设置、关于等
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),

      body: ListView(
        children: [
          // 播放设置
          _buildSectionHeader('播放设置'),
          _buildListTile(
            icon: Icons.high_quality,
            title: '音质选择',
            subtitle: '高品质',
            onTap: () => _showQualityPicker(context),
          ),
          _buildListTile(
            icon: Icons.repeat,
            title: '播放模式',
            subtitle: '列表循环',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.speed,
            title: '倍速播放',
            subtitle: '1.0x',
            onTap: () {},
          ),

          const Divider(),

          // OSS 同步配置
          _buildSectionHeader('OSS 同步配置'),
          _buildListTile(
            icon: Icons.cloud,
            title: 'Bucket',
            subtitle: '未配置',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.public,
            title: 'Endpoint',
            subtitle: '未配置',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.key,
            title: 'AccessKey / SecretKey',
            subtitle: '未配置',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.folder,
            title: '同步目录',
            subtitle: '未选择',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.timer,
            title: '同步频率',
            subtitle: '每30分钟',
            onTap: () {},
          ),

          const Divider(),

          // 封面歌词
          _buildSectionHeader('封面歌词'),
          _buildSwitchTile(
            icon: Icons.image,
            title: '自动补全封面',
            value: true,
            onChanged: (value) {},
          ),
          _buildSwitchTile(
            icon: Icons.lyrics,
            title: '自动补全歌词',
            value: false,
            onChanged: (value) {},
          ),

          const Divider(),

          // 其他
          _buildSectionHeader('其他'),
          _buildListTile(
            icon: Icons.category,
            title: '管理分类',
            subtitle: '',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.delete_outline,
            title: '缓存清理',
            subtitle: '0 MB',
            onTap: () => _showClearCacheDialog(context),
          ),

          const Divider(),

          // 关于
          _buildSectionHeader('关于'),
          _buildListTile(
            icon: Icons.info_outline,
            title: '版本',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.feedback_outlined,
            title: '反馈',
            subtitle: '',
            onTap: () {},
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1DB954),
        ),
      ),
    );
  }

  /// 普通列表项
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFB3B3B3)),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFFB3B3B3)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFB3B3B3)),
      onTap: onTap,
    );
  }

  /// Switch 列表项
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFB3B3B3)),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF1DB954),
      ),
    );
  }

  /// 显示音质选择器（临时弹窗）
  void _showQualityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音质选择',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('普通'),
              subtitle: const Text('128 kbps'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('高品质'),
              subtitle: const Text('320 kbps'),
              trailing: const Icon(Icons.check, color: Color(0xFF1DB954)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('无损'),
              subtitle: const Text('FLAC'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示清除缓存确认对话框
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 执行清理
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text(
              '确定',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}