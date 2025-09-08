import 'api_manager.dart';
import '../utils/global_config.dart';
import '../utils/app_logger.dart';

/// 用户喜欢歌曲列表服务
class LikelistService {
  static final LikelistService _instance = LikelistService._internal();
  factory LikelistService() => _instance;
  LikelistService._internal();

  /// 获取全局配置实例
  GlobalConfig get _globalConfig => GlobalConfig();

  /// 获取用户喜欢的歌曲列表
  /// 
  /// [uid] 用户ID，如果不传则从保存的用户信息中获取
  Future<List<int>?> getUserLikelist({String? uid}) async {
    try {
      // 获取用户ID
      final targetUid = uid ?? _getUserIdFromSavedInfo();
      if (targetUid == null) {
        AppLogger.warning('无法获取喜欢列表：用户ID未知');
        return null;
      }

      AppLogger.api('正在获取用户喜欢列表，uid: $targetUid');
      
      // 获取用户 cookie
      final cookie = _globalConfig.getUserCookie() ?? '';
      AppLogger.api('使用的 Cookie 长度: ${cookie.length}');
      
      final result = await ApiManager().api.likelist(
        uid: targetUid.toString(),
        cookie: cookie,
      );
      
      if (result['status'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>;
        
        AppLogger.api('Likelist body: $body');
        
        if (body['ids'] != null) {
          List<int> songIds = [];
          
          if (body['ids'] is List) {
            // 如果是数组，直接转换
            songIds = (body['ids'] as List).cast<int>();
          } else if (body['ids'] is String) {
            // 如果是字符串，按逗号分割并转换为整数
            final idsString = body['ids'] as String;
            if (idsString.isNotEmpty) {
              try {
                songIds = idsString
                    .split(',')
                    .where((id) => id.trim().isNotEmpty)
                    .map((id) => int.parse(id.trim()))
                    .toList();
              } catch (e) {
                AppLogger.error('解析喜欢列表字符串失败: $e');
                return null;
              }
            }
          } else {
            AppLogger.warning('Likelist body中ids字段类型未知: ${body['ids'].runtimeType}');
            return null;
          }
          
          // 保存到本地配置以供离线检查
          try {
            await _globalConfig.setUserLikelist(songIds);
          } catch (saveError) {
            AppLogger.error('保存喜欢列表到本地失败: $saveError');
            // 尝试清理可能损坏的数据
            await _globalConfig.cleanupLikelistData();
            // 重新尝试保存
            try {
              await _globalConfig.setUserLikelist(songIds);
            } catch (retryError) {
              AppLogger.error('重新保存喜欢列表失败: $retryError');
            }
          }
          
          AppLogger.api('喜欢列表获取成功，共${songIds.length}首歌曲: ${songIds.take(10).toList()}...');
          return songIds;
        } else {
          AppLogger.warning('Likelist body中没有找到ids字段');
        }
      } else {
        AppLogger.warning('Likelist API 返回状态异常: status=${result['status']}, body=${result['body']}');
      }

      AppLogger.warning('喜欢列表获取失败：响应格式不正确');
      return null;
    } catch (e) {
      AppLogger.error('获取喜欢列表异常', e);
      return null;
    }
  }

  /// 检查歌曲是否在喜欢列表中
  bool isLikedSong(int songId) {
    return _globalConfig.isLikedSong(songId);
  }

  /// 获取缓存的喜欢列表
  List<int> getCachedLikelist() {
    return _globalConfig.getUserLikelist();
  }

  /// 清除缓存的喜欢列表
  Future<void> clearCachedLikelist() async {
    await _globalConfig.setUserLikelist([]);
  }

  /// 从保存的信息中获取用户ID
  String? _getUserIdFromSavedInfo() {
    try {
      final userInfo = _globalConfig.getUserInfo();
      AppLogger.api('保存的用户信息: $userInfo');
      final userId = userInfo?['userId'];
      AppLogger.api('提取的用户ID: $userId');
      return userId?.toString();
    } catch (e) {
      AppLogger.error('获取用户ID失败', e);
      return null;
    }
  }

  /// 在应用启动时初始化喜欢列表
  /// 如果用户已登录且有cookie和uid，则获取喜欢列表
  Future<void> initializeLikelistOnStartup() async {
    try {
      AppLogger.api('开始检查应用启动时的喜欢列表初始化条件...');
      
      // 检查是否已登录
      final isLoggedIn = _globalConfig.isLoggedIn();
      AppLogger.api('用户登录状态: $isLoggedIn');
      if (!isLoggedIn) {
        AppLogger.api('用户未登录，跳过初始化喜欢列表');
        return;
      }

      // 检查是否有cookie
      final cookie = _globalConfig.getUserCookie();
      AppLogger.api('Cookie长度: ${cookie?.length ?? 0}');
      if (cookie == null || cookie.isEmpty) {
        AppLogger.api('未找到Cookie，跳过初始化喜欢列表');
        return;
      }

      // 检查是否有用户ID
      final uid = _getUserIdFromSavedInfo();
      AppLogger.api('获取到的用户ID: $uid');
      if (uid == null) {
        AppLogger.api('未找到用户ID，跳过初始化喜欢列表');
        return;
      }

      AppLogger.api('应用启动时初始化喜欢列表，uid: $uid');
      await getUserLikelist(uid: uid);
    } catch (e) {
      AppLogger.error('应用启动时初始化喜欢列表失败', e);
    }
  }

  /// 在登录后刷新喜欢列表
  /// 登录成功并获取到uid后调用此方法
  Future<void> refreshLikelistAfterLogin(String uid) async {
    try {
      AppLogger.api('登录后刷新喜欢列表，uid: $uid');
      await getUserLikelist(uid: uid);
    } catch (e) {
      AppLogger.error('登录后刷新喜欢列表失败', e);
    }
  }
}
