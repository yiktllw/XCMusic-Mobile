import '../models/album.dart';
import '../services/api_manager.dart';
import '../utils/global_config.dart';
import '../utils/app_logger.dart';

/// 专辑服务类
class AlbumService {
  final ApiManager _apiManager = ApiManager();
  final GlobalConfig _globalConfig = GlobalConfig();

  /// 获取已收藏的专辑列表
  Future<AlbumSublistResponse?> getSubscribedAlbums({
    int limit = 30,
    int offset = 0,
    bool latest = false,
  }) async {
    try {
      final userCookie = _globalConfig.getUserCookie();
      if (userCookie == null) {
        AppLogger.warning('用户未登录，无法获取专辑列表');
        return null;
      }

      dynamic result;
      if (latest) {
        result = await _apiManager.api.albumSublist(
          limit: limit,
          offset: offset,
          cookie: userCookie,
          timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } else {
        result = await _apiManager.api.albumSublist(
          limit: limit,
          offset: offset,
          cookie: userCookie,
        );
      }

      if (result['status'] == 200 && result['body'] != null) {
        final response = AlbumSublistResponse.fromJson(result);
        return response;
      } else {
        AppLogger.error('获取专辑列表失败: ${result['status']}');
        return null;
      }
    } catch (e) {
      AppLogger.error('获取专辑列表异常', e);
      return null;
    }
  }

  /// 获取所有已收藏的专辑（分页获取）
  Future<List<Album>> getAllSubscribedAlbums({bool latest = false}) async {
    final allAlbums = <Album>[];
    int offset = 0;
    const int limit = 30;

    try {
      while (true) {
        final response = await getSubscribedAlbums(
          limit: limit,
          offset: offset,
          latest: latest,
        );

        if (response == null || response.albums.isEmpty) {
          break;
        }

        allAlbums.addAll(response.albums);

        if (!response.hasMore) {
          break;
        }

        offset += limit;
      }
    } catch (e) {
      AppLogger.error('获取所有专辑列表异常', e);
    }

    return allAlbums;
  }

  /// 检查用户是否已登录
  bool isUserLoggedIn() {
    return _globalConfig.isLoggedIn();
  }
}
