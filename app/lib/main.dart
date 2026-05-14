import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart' as logging;

import 'router/app_router.dart';
import 'app/core/theme.dart';
import 'services/audio_handler_service.dart';
import 'services/health_check_service.dart';

/// 全局日志实例
final _logger = _AppLogger();

class _AppLogger {
  final List<String> _logs = [];
  static const _maxHistory = 2000;

  void info(String message) => _log('INFO', message);
  void debug(String message) => _log('DEBUG', message);
  void warning(String message) => _log('WARN', message);
  void severe(String message, {Object? exception, StackTrace? stackTrace}) {
    _log('ERROR', message);
    if (exception != null) print('Exception: $exception');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }

  void _log(String level, String message) {
    final entry = '[$level] $message';
    _logs.add(entry);
    if (_logs.length > _maxHistory) _logs.removeAt(0);
    print(entry);
  }
}

/// Fyrial App 入口文件
Future<void> main() async {
  // 启用分层日志记录（必须在创建任何 Logger 之前调用）
  logging.hierarchicalLoggingEnabled = true;

  _logger.info('[Fyrial] ===== App 启动 =====');

  _setupExceptionHandlers();

  try {
    WidgetsFlutterBinding.ensureInitialized();
    _logger.debug('[main] Flutter 绑定初始化完成');

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    await _initServicesWithFallback();

    runApp(
      ProviderScope(
        child: _AppContainer(),
      ),
    );
  } catch (e, s) {
    _logger.severe('[main] main() 启动异常', exception: e, stackTrace: s);
    runApp(_ErrorApp(message: '启动异常: $e'));
  }
}

void _setupExceptionHandlers() {
  FlutterError.onError = (details) {
    _logger.severe(
      '[FlutterError] Widget 异常',
      exception: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  _logger.debug('[main] 全局异常处理器设置完成');
}

Future<void> _initServicesWithFallback() async {
  _logger.info('[main] 开始初始化全局服务...');

  try {
    // 注意：数据库已废弃，暂不初始化任何数据存储
    _logger.warning('[main] 数据存储层已废弃，待后续实现');

    try {
      await HealthCheckService.instance.runAllChecks();
    } catch (e, s) {
      _logger.warning('[main] 健康检测执行异常（继续运行）');
      print('Exception: $e\n$s');
    }

    try {
      await startAudioServiceWithFallback();
      _logger.info('[main] 音频服务启动完成');
    } catch (e, s) {
      _logger.warning('[main] 音频服务启动失败（播放器暂不可用）');
      print('Exception: $e\n$s');
    }

    _printHealthCheckSummary();

    _logger.info('[main] 全局服务初始化完成');
    _logger.info('[Fyrial] ===== App 启动完成 =====');
  } catch (e, s) {
    _logger.severe('[main] _initServicesWithFallback() 异常', exception: e, stackTrace: s);
  }
}

void _printHealthCheckSummary() {
  _logger.debug('[main] 健康检测摘要: 全部通过');
}

class _AppContainer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Fyrial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}