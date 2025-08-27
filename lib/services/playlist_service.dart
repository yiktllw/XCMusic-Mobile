import '../models/playlist.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';
import '../utils/global_config.dart';

/// 歌单相关服务
class PlaylistService {
  static final _api = NeteaseCloudMusicApiFinal();
  static bool _initialized = false;

  /// 初始化API
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _api.init();
      _initialized = true;
    }
  }

  /// 获取歌单详情
  /// 
  /// [playlistId] 歌单ID
  /// [s] 歌单最近的 `s` 个收藏者，默认为8
  static Future<PlaylistDetail> getPlaylistDetail({
    required String playlistId,
    String? s,
  }) async {
    await _ensureInitialized();

    try {
      final response = await _api.api.playlistDetail(
        id: playlistId,
        s: s ?? '8',
        cookie: GlobalConfig().getUserCookie(),
        timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 检查响应状态
      final body = response['body'] as Map<String, dynamic>?;
      if (body == null) {
        throw Exception('获取歌单详情失败: 响应为空');
      }
      
      if (body['code'] != 200) {
        final message = body['message'] ?? body['msg'] ?? '未知错误';
        throw Exception('获取歌单详情失败: $message');
      }

      return PlaylistDetail.fromJson(body);
    } catch (e) {
      if (e.toString().contains('type null is not a subtype')) {
        throw Exception('歌单数据格式错误，请检查网络连接或稍后重试');
      }
      throw Exception('获取歌单详情失败: $e');
    }
  }

  /// 获取歌单的所有歌曲（支持分页加载更多歌曲）
  /// 
  /// [playlistId] 歌单ID
  /// [limit] 每页数量，默认1000
  /// [offset] 偏移量，默认0
  static Future<List<Track>> getPlaylistTracks({
    required String playlistId,
    int limit = 1000,
    int offset = 0,
  }) async {
    await _ensureInitialized();

    try {
      final response = await _api.api.playlistTrackAll(
        id: playlistId,
        limit: limit,
        offset: offset,
        cookie: GlobalConfig().getUserCookie(),
        timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 检查响应状态
      final body = response['body'] as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) {
        throw Exception('获取歌单歌曲失败: ${body?['message'] ?? '未知错误'}');
      }

      final songs = body['songs'] as List?;
      if (songs == null || songs.isEmpty) {
        return [];
      }

      try {
        return songs
            .map((song) => Track.fromJson(song as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw Exception('解析歌曲数据失败: $e');
      }
    } catch (e) {
      throw Exception('获取歌单歌曲失败: $e');
    }
  }

  /// 搜索歌单中的歌曲
  /// 
  /// [tracks] 歌曲列表
  /// [keyword] 搜索关键词
  static List<Track> searchTracks(List<Track> tracks, String keyword) {
    if (keyword.isEmpty) return tracks;

    final lowerKeyword = keyword.toLowerCase();
    return tracks.where((track) {
      return track.name.toLowerCase().contains(lowerKeyword) ||
          track.artistNames.toLowerCase().contains(lowerKeyword) ||
          track.album.name.toLowerCase().contains(lowerKeyword);
    }).toList();
  }

  /// 根据歌曲ID查找歌曲在列表中的索引
  /// 
  /// [tracks] 歌曲列表
  /// [trackId] 歌曲ID
  static int findTrackIndex(List<Track> tracks, int trackId) {
    return tracks.indexWhere((track) => track.id == trackId);
  }

  /// 批量获取歌曲详情（用于补充不完整的歌曲信息）
  /// 
  /// [trackIds] 歌曲ID列表
  static Future<List<Track>> getSongDetails(List<int> trackIds) async {
    await _ensureInitialized();

    try {
      final idsString = trackIds.join(',');
      final response = await _api.api.songDetail(
        ids: idsString,
        cookie: GlobalConfig().getUserCookie(),
        timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      // 检查响应状态
      final body = response['body'] as Map<String, dynamic>?;
      if (body == null || body['code'] != 200) {
        throw Exception('获取歌曲详情失败: ${body?['message'] ?? '未知错误'}');
      }

      final songs = body['songs'] as List?;
      if (songs == null || songs.isEmpty) {
        return [];
      }

      try {
        return songs
            .map((song) => Track.fromJson(song as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw Exception('解析歌曲数据失败: $e');
      }
    } catch (e) {
      throw Exception('获取歌曲详情失败: $e');
    }
  }
}
