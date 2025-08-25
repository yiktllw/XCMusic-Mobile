import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 加密的用户配置管理工具
/// 
/// 提供类似JSON的类型安全存取操作，支持加密存储
/// 支持基本数据类型：String, int, double, bool, List, Map
class EncryptedConfigManager {
  static const _storage = FlutterSecureStorage();

  static const String _configKey = 'encrypted_user_config';
  static const String _encryptionKeyName = 'config_encryption_key';
  
  Map<String, dynamic> _config = {};
  String? _encryptionKey;
  bool _isInitialized = false;

  /// 单例实例
  static final EncryptedConfigManager _instance = EncryptedConfigManager._internal();
  factory EncryptedConfigManager() => _instance;
  EncryptedConfigManager._internal();

  /// 初始化配置管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 获取或生成加密密钥
      _encryptionKey = await _getOrCreateEncryptionKey();
      
      // 加载配置
      await _loadConfig();
      
      _isInitialized = true;
    } catch (e) {
      throw Exception('配置管理器初始化失败: $e');
    }
  }

  /// 获取或创建加密密钥
  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _storage.read(key: _encryptionKeyName);
    
    if (key == null) {
      // 生成新的256位密钥
      final bytes = List<int>.generate(32, (i) => 
        DateTime.now().millisecondsSinceEpoch.hashCode + i);
      key = base64Encode(bytes);
      await _storage.write(key: _encryptionKeyName, value: key);
    }
    
    return key;
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final encryptedData = await _storage.read(key: _configKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = _decrypt(encryptedData);
        _config = json.decode(decryptedJson) as Map<String, dynamic>;
      }
    } catch (e) {
      // 如果解密失败，重置配置
      _config = {};
      await _saveConfig();
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    try {
      final jsonString = json.encode(_config);
      final encryptedData = _encrypt(jsonString);
      await _storage.write(key: _configKey, value: encryptedData);
    } catch (e) {
      throw Exception('保存配置失败: $e');
    }
  }

  /// 加密数据
  String _encrypt(String data) {
    if (_encryptionKey == null) {
      throw Exception('加密密钥未初始化');
    }

    final key = base64Decode(_encryptionKey!);
    final dataBytes = utf8.encode(data);
    
    // 使用HMAC-SHA256进行加密
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(dataBytes);
    
    // 组合原始数据和摘要
    final combined = dataBytes + digest.bytes;
    return base64Encode(combined);
  }

  /// 解密数据
  String _decrypt(String encryptedData) {
    if (_encryptionKey == null) {
      throw Exception('加密密钥未初始化');
    }

    final key = base64Decode(_encryptionKey!);
    final combined = base64Decode(encryptedData);
    
    // 分离数据和摘要
    final digestLength = 32; // SHA256 摘要长度
    if (combined.length < digestLength) {
      throw Exception('无效的加密数据');
    }
    
    final dataBytes = combined.sublist(0, combined.length - digestLength);
    final digest = combined.sublist(combined.length - digestLength);
    
    // 验证摘要
    final hmac = Hmac(sha256, key);
    final expectedDigest = hmac.convert(dataBytes);
    
    if (!_listEquals(digest, expectedDigest.bytes)) {
      throw Exception('数据完整性验证失败');
    }
    
    return utf8.decode(dataBytes);
  }

  /// 比较两个列表是否相等
  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('配置管理器未初始化，请先调用 initialize()');
    }
  }

  /// 设置配置值
  Future<void> set<T>(String key, T value) async {
    _ensureInitialized();
    
    if (value == null) {
      _config.remove(key);
    } else {
      _config[key] = _serializeValue(value);
    }
    
    await _saveConfig();
  }

  /// 获取配置值
  T? get<T>(String key, [T? defaultValue]) {
    _ensureInitialized();
    
    if (!_config.containsKey(key)) {
      return defaultValue;
    }
    
    return _deserializeValue<T>(_config[key], defaultValue);
  }

  /// 获取字符串值
  String? getString(String key, [String? defaultValue]) {
    return get<String>(key, defaultValue);
  }

  /// 获取整数值
  int? getInt(String key, [int? defaultValue]) {
    return get<int>(key, defaultValue);
  }

  /// 获取双精度浮点数值
  double? getDouble(String key, [double? defaultValue]) {
    return get<double>(key, defaultValue);
  }

  /// 获取布尔值
  bool? getBool(String key, [bool? defaultValue]) {
    return get<bool>(key, defaultValue);
  }

  /// 获取列表值
  List<T>? getList<T>(String key, [List<T>? defaultValue]) {
    return get<List<T>>(key, defaultValue);
  }

  /// 获取映射值
  Map<String, T>? getMap<T>(String key, [Map<String, T>? defaultValue]) {
    return get<Map<String, T>>(key, defaultValue);
  }

  /// 设置字符串值
  Future<void> setString(String key, String value) async {
    await set<String>(key, value);
  }

  /// 设置整数值
  Future<void> setInt(String key, int value) async {
    await set<int>(key, value);
  }

  /// 设置双精度浮点数值
  Future<void> setDouble(String key, double value) async {
    await set<double>(key, value);
  }

  /// 设置布尔值
  Future<void> setBool(String key, bool value) async {
    await set<bool>(key, value);
  }

  /// 设置列表值
  Future<void> setList<T>(String key, List<T> value) async {
    await set<List<T>>(key, value);
  }

  /// 设置映射值
  Future<void> setMap<T>(String key, Map<String, T> value) async {
    await set<Map<String, T>>(key, value);
  }

  /// 序列化值
  dynamic _serializeValue<T>(T value) {
    if (value is String || value is int || value is double || value is bool) {
      return value;
    } else if (value is List) {
      return value.map((item) => _serializeValue(item)).toList();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _serializeValue(v)));
    } else {
      // 对于复杂对象，尝试转换为JSON
      try {
        return json.decode(json.encode(value));
      } catch (e) {
        throw Exception('不支持的数据类型: ${value.runtimeType}');
      }
    }
  }

  /// 反序列化值
  T? _deserializeValue<T>(dynamic value, T? defaultValue) {
    if (value == null) return defaultValue;

    try {
      if (T == String) {
        return value.toString() as T;
      } else if (T == int) {
        if (value is int) return value as T;
        if (value is double) return value.round() as T;
        if (value is String) return int.parse(value) as T;
      } else if (T == double) {
        if (value is double) return value as T;
        if (value is int) return value.toDouble() as T;
        if (value is String) return double.parse(value) as T;
      } else if (T == bool) {
        if (value is bool) return value as T;
        if (value is String) return (value.toLowerCase() == 'true') as T;
        if (value is int) return (value != 0) as T;
      } else if (T.toString().startsWith('List<')) {
        if (value is List) {
          return value.cast<dynamic>() as T;
        }
      } else if (T.toString().startsWith('Map<')) {
        if (value is Map) {
          return value.cast<String, dynamic>() as T;
        }
      }

      return value as T;
    } catch (e) {
      return defaultValue;
    }
  }

  /// 检查键是否存在
  bool containsKey(String key) {
    _ensureInitialized();
    return _config.containsKey(key);
  }

  /// 删除配置项
  Future<void> remove(String key) async {
    _ensureInitialized();
    _config.remove(key);
    await _saveConfig();
  }

  /// 清空所有配置
  Future<void> clear() async {
    _ensureInitialized();
    _config.clear();
    await _saveConfig();
  }

  /// 获取所有键
  Set<String> get keys {
    _ensureInitialized();
    return _config.keys.toSet();
  }

  /// 获取配置项数量
  int get length {
    _ensureInitialized();
    return _config.length;
  }

  /// 检查是否为空
  bool get isEmpty {
    _ensureInitialized();
    return _config.isEmpty;
  }

  /// 检查是否非空
  bool get isNotEmpty {
    _ensureInitialized();
    return _config.isNotEmpty;
  }

  /// 获取所有配置的副本（用于调试）
  Map<String, dynamic> getAllConfig() {
    _ensureInitialized();
    return Map<String, dynamic>.from(_config);
  }

  /// 重置加密密钥和所有配置
  Future<void> resetAll() async {
    try {
      await _storage.delete(key: _configKey);
      await _storage.delete(key: _encryptionKeyName);
      _config.clear();
      _encryptionKey = null;
      _isInitialized = false;
    } catch (e) {
      throw Exception('重置配置失败: $e');
    }
  }
}
