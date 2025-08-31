import 'dart:convert';
import '../utils/global_config.dart';

/// 搜索历史管理类
class SearchHistoryService {
  static const String _keySearchHistory = 'search_history';
  static const int _maxHistoryCount = 10;

  /// 获取搜索历史
  static List<String> getSearchHistory() {
    try {
      final historyJson = GlobalConfig().get<String>(_keySearchHistory);
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        return historyList.cast<String>();
      }
    } catch (e) {
      print('获取搜索历史失败: $e');
    }
    return [];
  }

  /// 添加搜索历史
  static Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    try {
      List<String> history = getSearchHistory();

      // 移除相同的搜索记录（如果存在）
      history.remove(query);

      // 将新搜索记录添加到最前面
      history.insert(0, query);

      // 保持最多10个记录
      if (history.length > _maxHistoryCount) {
        history = history.take(_maxHistoryCount).toList();
      }

      // 保存到本地存储
      await GlobalConfig().set(_keySearchHistory, jsonEncode(history));
    } catch (e) {
      print('保存搜索历史失败: $e');
    }
  }

  /// 删除指定的搜索历史
  static Future<void> removeSearchHistory(String query) async {
    try {
      List<String> history = getSearchHistory();
      history.remove(query);
      await GlobalConfig().set(_keySearchHistory, jsonEncode(history));
    } catch (e) {
      print('删除搜索历史失败: $e');
    }
  }

  /// 清空所有搜索历史
  static Future<void> clearSearchHistory() async {
    try {
      await GlobalConfig().remove(_keySearchHistory);
    } catch (e) {
      print('清空搜索历史失败: $e');
    }
  }
}
