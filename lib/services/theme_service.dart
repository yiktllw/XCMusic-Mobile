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
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
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
