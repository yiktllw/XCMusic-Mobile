import 'dart:convert';
import 'encrypted_config_manager.dart';

/// 全局配置管理器
///
/// 提供应用级别的配置管理，基于 EncryptedConfigManager
/// 这个类提供了应用中常用配置的便捷访问方法
class GlobalConfig {
  static final GlobalConfig _instance = GlobalConfig._internal();
  factory GlobalConfig() => _instance;
  GlobalConfig._internal();

  // 底层配置管理器
  final EncryptedConfigManager _configManager = EncryptedConfigManager();

  bool _isInitialized = false;

  /// 初始化全局配置
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _configManager.initialize();
    _isInitialized = true;
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('GlobalConfig 未初始化，请先调用 initialize()');
    }
  }

  // ==================== 常用配置键名定义 ====================

  /// 用户登录相关
  static const String userCookieKey = 'user_cookie';
  static const String userInfoKey = 'user_info';
  static const String isLoggedInKey = 'is_logged_in';

  /// 应用设置
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String volumeKey = 'volume';

  /// 音乐播放相关
  static const String playlistKey = 'current_playlist';
  static const String currentSongKey = 'current_song';
  static const String playModeKey = 'play_mode';

  // ==================== 用户登录相关方法 ====================

  /// 设置用户Cookie
  Future<void> setUserCookie(String cookie) async {
    _ensureInitialized();
    await _configManager.setString(userCookieKey, cookie);
  }

  /// 获取用户Cookie
  String? getUserCookie() {
    _ensureInitialized();
    return _configManager.getString(userCookieKey);
  }

  /// 设置登录状态
  Future<void> setLoggedIn(bool isLoggedIn) async {
    _ensureInitialized();
    await _configManager.setBool(isLoggedInKey, isLoggedIn);
  }

  /// 检查是否已登录
  bool isLoggedIn() {
    _ensureInitialized();
    return _configManager.getBool(isLoggedInKey) ?? false;
  }

  /// 设置用户信息
  Future<void> setUserInfo(Map<String, dynamic> userInfo) async {
    _ensureInitialized();
    await _configManager.setString(userInfoKey, jsonEncode(userInfo));
  }

  /// 获取用户信息
  Map<String, dynamic>? getUserInfo() {
    _ensureInitialized();
    final userInfoStr = _configManager.getString(userInfoKey);
    if (userInfoStr != null && userInfoStr.isNotEmpty) {
      try {
        return jsonDecode(userInfoStr) as Map<String, dynamic>;
      } catch (e) {
        print('[CONFIG] 解析用户信息JSON失败: $e');
        return null;
      }
    }
    return null;
  }

  /// 清除用户数据
  Future<void> clearUserData() async {
    _ensureInitialized();
    await _configManager.remove(userCookieKey);
    await _configManager.remove(userInfoKey);
    await _configManager.remove(isLoggedInKey);
  }

  // ==================== 应用设置相关方法 ====================

  /// 设置主题模式
  Future<void> setThemeMode(String themeMode) async {
    _ensureInitialized();
    await _configManager.setString(themeKey, themeMode);
  }

  /// 获取主题模式
  String getThemeMode() {
    _ensureInitialized();
    return _configManager.getString(themeKey) ?? 'system';
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    _ensureInitialized();
    await _configManager.setString(languageKey, language);
  }

  /// 获取语言
  String getLanguage() {
    _ensureInitialized();
    return _configManager.getString(languageKey) ?? 'zh-CN';
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _ensureInitialized();
    await _configManager.setDouble(volumeKey, volume);
  }

  /// 获取音量
  double getVolume() {
    _ensureInitialized();
    return _configManager.getDouble(volumeKey) ?? 0.5;
  }

  // ==================== 通用配置方法 ====================

  /// 设置配置值
  Future<void> set<T>(String key, T value) async {
    _ensureInitialized();
    await _configManager.set(key, value);
  }

  /// 获取配置值
  T? get<T>(String key, [T? defaultValue]) {
    _ensureInitialized();
    return _configManager.get<T>(key, defaultValue);
  }

  /// 移除配置项
  Future<void> remove(String key) async {
    _ensureInitialized();
    await _configManager.remove(key);
  }

  /// 清空所有配置
  Future<void> clear() async {
    _ensureInitialized();
    await _configManager.resetAll();
    _isInitialized = false;
  }

  /// 获取所有配置键
  Set<String> get keys {
    _ensureInitialized();
    return _configManager.keys;
  }

  /// 获取配置项数量
  int get length {
    _ensureInitialized();
    return _configManager.length;
  }

  /// 获取所有配置的副本（用于调试）
  Map<String, dynamic> getAllConfig() {
    _ensureInitialized();
    return _configManager.getAllConfig();
  }
}
