import 'package:logging/logging.dart' as logging;

/// 数据库助手 - 已废弃
/// 注意：本项目数据存储层已废弃，此类仅保留用于兼容性
/// 所有方法均为空实现，仅打印日志
class DatabaseHelper {
  static const _tag = '[DatabaseHelper]';
  static final _logger = logging.Logger(_tag)..level = logging.Level.ALL;

  // 单例模式
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  /// 获取数据库实例（已废弃，返回 null）
  Future<dynamic> get db async {
    _logger.warning('[废弃] DatabaseHelper.db 已被废弃');
    return null;
  }

  /// 初始化数据库（已废弃）
  @Deprecated('数据存储层已废弃')
  Future<void> init() async {
    _logger.warning('[废弃] DatabaseHelper.init() 已被废弃');
  }

  /// 健康检查（已废弃）
  @Deprecated('数据存储层已废弃')
  Future<bool> healthCheck() async {
    _logger.warning('[废弃] DatabaseHelper.healthCheck() 已被废弃');
    return false;
  }

  /// 关闭数据库（已废弃）
  @Deprecated('数据存储层已废弃')
  Future<void> close() async {
    _logger.warning('[废弃] DatabaseHelper.close() 已被废弃');
  }

  /// 是否使用内存模式（已废弃）
  @Deprecated('已废弃')
  bool get isMemoryMode {
    _logger.warning('[废弃] DatabaseHelper.isMemoryMode 已被废弃');
    return false;
  }

  /// 设置内存模式（已废弃）
  @Deprecated('已废弃')
  void setMemoryMode() {
    _logger.warning('[废弃] DatabaseHelper.setMemoryMode() 已被废弃');
  }
}
