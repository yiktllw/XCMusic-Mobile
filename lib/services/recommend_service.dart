import '../utils/app_logger.dart';
import '../models/playlist.dart';
import '../utils/global_config.dart';
import 'api_manager.dart';

/// 推荐歌曲服务
class RecommendService {
  static final RecommendService _instance = RecommendService._internal();
  factory RecommendService() => _instance;
  RecommendService._internal();
  
  final GlobalConfig _globalConfig = GlobalConfig();

  /// 获取推荐歌曲
  Future<List<Track>> getRecommendedSongs() async {
    try {
      if (!ApiManager().isInitialized) {
        throw Exception('ApiManager 未初始化');
      }

      AppLogger.info('正在获取推荐歌曲...');
      
      final cookie = _globalConfig.getUserCookie() ?? '';
      
      final response = await ApiManager().api.recommendSongs(
        cookie: cookie,
      );

      if (response['status'] == 200 && response['body'] != null) {
        final body = response['body'] as Map<String, dynamic>;
        if (body['code'] == 200 && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          final dailySongs = data['dailySongs'] as List?;
          
          if (dailySongs != null && dailySongs.isNotEmpty) {
            AppLogger.info('成功获取${dailySongs.length}首推荐歌曲');
            return dailySongs
                .map((song) => Track.fromJson(song as Map<String, dynamic>))
                .toList();
          }
        }
      }

      throw Exception('推荐歌曲响应格式不正确');
    } catch (e) {
      AppLogger.error('获取推荐歌曲失败', e);
      return [];
    }
  }
}
