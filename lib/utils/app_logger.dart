import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';

/// 统一的日志管理器
///
/// 提供应用级别的日志记录功能，支持不同级别的日志输出
/// 开发模式下会显示详细的日志信息，生产模式下会过滤部分日志
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  late final Logger _logger;
  bool _isInitialized = false;

  /// 初始化日志管理器
  void initialize() {
    if (_isInitialized) return;

    _logger = Logger(
      filter: _AppLogFilter(),
      printer: _CustomPrettyPrinter(
        methodCount: 0, // 在普通日志中不显示调用堆栈
        errorMethodCount: 3, // 只在错误时显示少量堆栈信息
        lineLength: 120, // 每行最大长度
        colors: true, // 启用颜色输出
        printEmojis: true, // 显示表情符号
        noBoxingByDefault: true, // 不使用边框包装
        excludeBox: {Level.debug: true, Level.info: true}, // 对于debug和info级别不显示框
      ),
      output: ConsoleOutput(),
    );

    _isInitialized = true;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  // ==================== 日志记录方法 ====================

  /// 记录调试信息
  /// 用于开发时的详细信息输出
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger()._ensureInitialized();
    AppLogger()._logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 记录一般信息
  /// 用于重要的程序流程信息
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger()._ensureInitialized();
    AppLogger()._logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 记录警告信息
  /// 用于潜在的问题或异常情况
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger()._ensureInitialized();
    AppLogger()._logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 记录错误信息
  /// 用于错误和异常
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger()._ensureInitialized();
    AppLogger()._logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 记录严重错误信息
  /// 用于致命错误
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger()._ensureInitialized();
    AppLogger()._logger.f(message, error: error, stackTrace: stackTrace);
  }

  // ==================== 便捷的分类日志方法 ====================

  /// API 相关日志
  static void api(String message, [dynamic error, StackTrace? stackTrace]) {
    info('[API] $message', error, stackTrace);
  }

  /// 配置相关日志
  static void config(String message, [dynamic error, StackTrace? stackTrace]) {
    info('[CONFIG] $message', error, stackTrace);
  }

  /// 缓存相关日志
  static void cache(String message, [dynamic error, StackTrace? stackTrace]) {
    debug('[CACHE] $message', error, stackTrace);
  }

  /// HTTP 请求相关日志
  static void http(String message, [dynamic error, StackTrace? stackTrace]) {
    debug('[HTTP] $message', error, stackTrace);
  }

  /// 应用程序相关日志
  static void app(String message, [dynamic error, StackTrace? stackTrace]) {
    info('[APP] $message', error, stackTrace);
  }

  /// UI 相关日志
  static void ui(String message, [dynamic error, StackTrace? stackTrace]) {
    debug('[UI] $message', error, stackTrace);
  }

  /// 创建API日志适配器
  /// 将API库的日志输出接入到应用的日志系统
  static ApiLogger createApiAdapter() {
    return _AppLoggerApiAdapter();
  }
}

/// AppLogger到ApiLogger的适配器
/// 将API库的日志输出适配到应用的日志系统
class _AppLoggerApiAdapter implements ApiLogger {
  @override
  void log(
    ApiLogLevel level,
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    switch (level) {
      case ApiLogLevel.debug:
        AppLogger.debug('$tag $message', error, stackTrace);
        break;
      case ApiLogLevel.info:
        AppLogger.info('$tag $message', error, stackTrace);
        break;
      case ApiLogLevel.warning:
        AppLogger.warning('$tag $message', error, stackTrace);
        break;
      case ApiLogLevel.error:
        AppLogger.error('$tag $message', error, stackTrace);
        break;
    }
  }
}

/// 自定义日志过滤器
/// 根据运行模式决定显示哪些级别的日志
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // 在调试模式下显示所有日志
    if (kDebugMode) {
      return true;
    }

    // 在生产模式下只显示警告及以上级别的日志
    return event.level.value >= Level.warning.value;
  }
}

/// 自定义PrettyPrinter，用于自定义日志颜色
class _CustomPrettyPrinter extends PrettyPrinter {
  _CustomPrettyPrinter({
    super.methodCount,
    super.errorMethodCount,
    super.lineLength,
    super.colors,
    super.printEmojis,
    super.noBoxingByDefault,
    super.excludeBox,
  });

  @override
  List<String> log(LogEvent event) {
    // 获取原始输出
    final originalOutput = super.log(event);

    // 如果不启用颜色，直接返回
    if (!colors) {
      return originalOutput;
    }

    // 为debug级别的日志添加绿色
    if (event.level == Level.debug) {
      return originalOutput.map((line) {
        // 如果行已经包含颜色代码，不重复添加
        if (line.contains('\x1B[')) {
          return line.replaceAll('\x1B[37m', '\x1B[32m'); // 将白色替换为绿色
        }
        return '\x1B[32m$line\x1B[0m'; // 绿色
      }).toList();
    }

    return originalOutput;
  }
}
