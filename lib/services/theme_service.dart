import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';

/// 主题服务
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  String _themeMode = 'system'; // 'light', 'dark', 'system'
  ThemeMode _currentThemeMode = ThemeMode.system;

  /// 获取当前主题模式
  String get themeMode => _themeMode;
  ThemeMode get currentThemeMode => _currentThemeMode;

  /// 浅色主题
  ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
  );

  /// 深色主题
  ThemeData get darkTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ).copyWith(
      // 自定义背景颜色，使用更浅的深灰色
      surface: const Color(0xFF2A2A2E),           // 主要表面色 - 浅深灰
      onSurface: const Color(0xFFE8E8EA),         // 表面上的文字颜色 - 更亮的浅灰
      surfaceContainerHighest: const Color(0xFF3A3A3E), // 最高容器表面 - 浅中灰
      surfaceContainer: const Color(0xFF323236),   // 容器表面 - 浅深灰
      surfaceContainerHigh: const Color(0xFF363639), // 高容器表面 - 中浅灰
      surfaceContainerLow: const Color(0xFF2D2D31),  // 低容器表面 - 接近背景的浅深灰
      outline: const Color(0xFF626268),            // 轮廓线颜色 - 更亮的中等灰色
      onSurfaceVariant: const Color(0xFFC8C8CA),   // 表面变体上的文字 - 更亮的浅灰
    ),
    scaffoldBackgroundColor: const Color(0xFF1E1E22), // 脚手架背景色 - 浅深灰
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF2A2A2E),         // AppBar背景色
      foregroundColor: Color(0xFFE8E8EA),         // AppBar前景色
    ),
  );

  /// 初始化主题设置
  Future<void> initialize() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _themeMode = prefs.getString('theme') ?? 'system';
        _updateThemeMode();
        AppLogger.info('主题服务初始化成功: $_themeMode');
        return; // 成功初始化，退出重试循环
      } catch (e) {
        retryCount++;
        AppLogger.error('主题服务初始化失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          AppLogger.warning('多次尝试后仍无法初始化主题服务，使用默认主题');
          _themeMode = 'system';
          _updateThemeMode();
        }
      }
    }
  }

  /// 设置主题
  Future<void> setTheme(String theme) async {
    if (_themeMode == theme) return;

    _themeMode = theme;
    _updateThemeMode();
    notifyListeners(); // 先通知界面更新

    // 异步保存设置，不阻塞界面更新
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme', theme);
        AppLogger.info('主题已设置为: $theme');
        return; // 成功保存，退出重试循环
      } catch (e) {
        retryCount++;
        AppLogger.error('保存主题设置失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          AppLogger.warning('多次尝试后仍无法保存主题设置');
        }
      }
    }
  }

  /// 更新主题模式
  void _updateThemeMode() {
    switch (_themeMode) {
      case 'light':
        _currentThemeMode = ThemeMode.light;
        break;
      case 'dark':
        _currentThemeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        _currentThemeMode = ThemeMode.system;
        break;
    }
  }

  /// 获取主题显示名称
  String getThemeDisplayName() {
    switch (_themeMode) {
      case 'light':
        return '浅色主题';
      case 'dark':
        return '深色主题';
      case 'system':
      default:
        return '跟随系统';
    }
  }
}
