import 'dart:async';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';

/// 全局API服务管理器
/// 确保整个应用程序共用一个API实例
class ApiManager {
  static final ApiManager _instance = ApiManager._internal();
  factory ApiManager() => _instance;
  ApiManager._internal();

  NeteaseCloudMusicApiFinal? _api;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// 获取API实例
  NeteaseCloudMusicApiFinal get api {
    if (!_initialized) {
      throw StateError('API未初始化，请先调用 ApiManager().init()');
    }
    return _api!;
  }

  /// 初始化API（应该在main函数中调用）
  Future<void> init() async {
    if (_initialized) return;
    
    // 如果正在初始化，等待初始化完成
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    _initCompleter = Completer<void>();
    
    try {
      print('正在初始化网易云音乐API...');
      _api = NeteaseCloudMusicApiFinal();
      await _api!.init();
      _initialized = true;
      print('网易云音乐API初始化完成');
      _initCompleter!.complete();
    } catch (e) {
      print('网易云音乐API初始化失败: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _initialized;

  /// 安全调用API方法（推荐使用新的类型安全方式）
  /// 
  /// 旧的调用方式（已弃用）:
  /// ```dart
  /// await ApiManager().call('loginQrKey', {});
  /// ```
  /// 
  /// 新的推荐调用方式:
  /// ```dart
  /// await ApiManager().api.call(ApiModules.loginQrKey, ApiParams.loginQrKey());
  /// ```
  @Deprecated('请使用 ApiManager().api.call(ApiModules.xxx, ApiParams.xxx()) 方式调用')
  Future<Map<String, dynamic>> call(String moduleName, Map<String, dynamic> params) async {
    if (!_initialized) {
      throw StateError('API未初始化，请先调用 ApiManager().init()');
    }
    return await _api!.call(moduleName, params);
  }

  /// 设置API日志开关
  void setApiLogging(bool enabled) {
    NeteaseCloudMusicApiFinal.setApiLogging(enabled);
  }

  /// 获取当前API日志开关状态
  bool getApiLogging() {
    return NeteaseCloudMusicApiFinal.getApiLogging();
  }

  /// 获取可用模块列表（调试用）
  List<String> getAvailableModules() {
    if (!_initialized) return [];
    return _api!.getAvailableModules();
  }

  /// 释放资源（应用退出时调用）
  void dispose() {
    _api = null;
    _initialized = false;
    _initCompleter = null;
  }
}
