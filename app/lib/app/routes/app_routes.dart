/// 路由名称常量
/// 统一管理所有路由名称，避免硬编码
abstract class Routes {
  Routes._();

  /// 初始页（闪屏/引导）
  static const String initial = '/';

  /// 主页（含底部 4 Tab 导航）
  static const String home = '/home';

  /// 全屏播放页
  static const String player = '/player';

  /// 搜索页
  static const String search = '/search';

  /// 歌单详情页
  static const String playlistDetail = '/playlist/:id';

  /// 统计详情页
  static const String statsDetail = '/stats-detail';

  /// OSS 设置页
  static const String ossSettings = '/settings/oss';
}