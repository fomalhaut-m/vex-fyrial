import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart' as logging;

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class AppLogService {
  static final AppLogService instance = AppLogService._();
  AppLogService._();

  final logging.Logger _logger = logging.Logger('Vexfy');
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  void init({LogLevel minLevel = LogLevel.debug}) {
    _minLevel = minLevel;
    logging.hierarchicalLoggingEnabled = true;
    _logger.level = _toLoggingLevel(_minLevel);
    
    _logger.onRecord.listen((record) {
      final levelStr = _levelString(record.level).padRight(7);
      final time = _formatTime(record.time);
      print('[$time] [Vexfy] $levelStr ${record.message}');
      if (record.error != null) {
        print('       错误: ${record.error}');
      }
      if (record.stackTrace != null) {
        print('       堆栈: ${_formatStackTrace(record.stackTrace!)}');
      }
    });

    d('AppLogService', '===== 日志服务初始化完成 =====');
    i('AppLogService', '日志级别: ${_levelString(_toLoggingLevel(_minLevel))}');
  }

  void setMinLevel(LogLevel level) {
    _minLevel = level;
    _logger.level = _toLoggingLevel(level);
    i('AppLogService', '日志级别已调整为: ${_levelString(_toLoggingLevel(level))}');
  }

  LogLevel get minLevel => _minLevel;

  void d(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.debug, tag, message, error, stack);

  void i(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.info, tag, message, error, stack);

  void w(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.warning, tag, message, error, stack);

  void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, error, stack);

  void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stack]) {
    final logLevel = _toLoggingLevel(level);
    if (logLevel.value < _logger.level.value) return;

    final fullMessage = '[$tag] $message';
    
    if (error != null && stack != null) {
      _logger.log(logLevel, fullMessage, error, stack);
    } else if (error != null) {
      _logger.log(logLevel, fullMessage, error);
    } else {
      _logger.log(logLevel, fullMessage);
    }
  }

  String _levelString(logging.Level level) {
    if (level == logging.Level.ALL || level.value <= 300) return 'DEBUG';
    if (level.value <= 500) return 'INFO ';
    if (level.value <= 700) return 'WARN ';
    return 'ERROR';
  }

  logging.Level _toLoggingLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return logging.Level.FINE;
      case LogLevel.info:
        return logging.Level.INFO;
      case LogLevel.warning:
        return logging.Level.WARNING;
      case LogLevel.error:
        return logging.Level.SEVERE;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}.'
           '${time.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatStackTrace(StackTrace stack) {
    return stack.toString().split('\n').take(8).join('\n       ');
  }
}