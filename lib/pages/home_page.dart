import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recommend_service.dart';
import '../services/player_service.dart';
import '../services/playlist_service.dart';
import '../models/playlist.dart';
import '../utils/app_logger.dart';
import '../config/song_list_layout.dart';
import '../widgets/song_detail_panel.dart';
import 'recommend_songs_page.dart';

/// 主页内容页面
class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final RecommendService _recommendService = RecommendService();
  List<Track> _recommendedSongs = [];
  List<RecommendedPlaylist> _recommendedPlaylists = [];
  bool _isLoading = true;
  bool _isPlaylistLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendedSongs();
    _loadRecommendedPlaylists();
  }

  /// 加载推荐歌曲
  Future<void> _loadRecommendedSongs() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final songs = await _recommendService.getRecommendedSongs();

      setState(() {
        _recommendedSongs = songs;
        _isLoading = false;
      });

      AppLogger.info('主页推荐歌曲加载完成: ${songs.length} 首');
    } catch (e) {
      AppLogger.error('加载推荐歌曲失败', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载推荐歌单
  Future<void> _loadRecommendedPlaylists() async {
    try {
      setState(() {
        _isPlaylistLoading = true;
      });

      final playlists = await PlaylistService.getRecommendedPlaylists();

      setState(() {
        _recommendedPlaylists = playlists;
        _isPlaylistLoading = false;
      });

      AppLogger.info('主页推荐歌单加载完成: ${playlists.length} 个');
    } catch (e) {
      AppLogger.error('加载推荐歌单失败', e);
      setState(() {
        _isPlaylistLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadRecommendedSongs(),
          _loadRecommendedPlaylists(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 推荐歌曲部分
            _buildRecommendedSongsSection(),
            
            const SizedBox(height: 16),
            
            // 推荐歌单部分
            _buildRecommendedPlaylistsSection(),
            
            // 底部空白
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// 构建推荐歌曲部分
  Widget _buildRecommendedSongsSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏 - 可点击跳转
          InkWell(
            onTap: _recommendedSongs.length > 3
                ? () => _navigateToRecommendPage()
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '每日推荐',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (_recommendedSongs.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 8), // 为>按钮添加右边距
                      child: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 推荐歌曲列表
          _isLoading
              ? _buildLoadingWidget()
              : _recommendedSongs.isEmpty
              ? _buildEmptyWidget()
              : _buildSongsList(),
        ],
      ),
    );
  }

  /// 构建加载中组件
  Widget _buildLoadingWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载推荐歌曲...'),
          ],
        ),
      ),
    );
  }

  /// 构建空状态组件
  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.music_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '暂无推荐歌曲',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '请检查网络连接或稍后重试',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendedSongs,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建歌曲列表
  Widget _buildSongsList() {
    // 只显示前3首歌曲作为预览
    final displaySongs = _recommendedSongs.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // 添加左右边距和底边距
      child: Column(
        children: [
          // 显示前3首歌曲
          ...displaySongs.asMap().entries.map((entry) {
            final index = entry.key;
            final track = entry.value;
            return _buildSongItem(track, index);
          }),
        ],
      ),
    );
  }

  /// 构建单个歌曲项
  Widget _buildSongItem(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context);
    final isCurrentPlaying = track.id == playerService.currentTrack?.id;

    return InkWell(
      onTap: () => _onTrackTap(track, index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8), // 只保留上下边距
        child: Row(
          children: [
            // 歌曲封面
            ClipRRect(
              borderRadius: BorderRadius.circular(
                SongListLayoutConfig.albumCoverRadius,
              ),
              child: Image.network(
                "${track.album.picUrl}${SongListLayoutConfig.albumCoverParam}",
                width: SongListLayoutConfig.albumCoverSize,
                height: SongListLayoutConfig.albumCoverSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: SongListLayoutConfig.albumCoverSize,
                    height: SongListLayoutConfig.albumCoverSize,
                    color: SongListStyleConfig.getErrorBackgroundColor(context),
                    child: Icon(
                      Icons.music_note,
                      color: SongListStyleConfig.getErrorIconColor(context),
                      size: SongListLayoutConfig.errorIconSize,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: SongListLayoutConfig.spacingMedium),

            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 歌曲名称和VIP标识
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.name,
                          style: SongListStyleConfig.getSongNameStyle(
                            context,
                            isCurrentPlaying: isCurrentPlaying,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (track.isVip) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: SongListLayoutConfig.vipPadding,
                          decoration: BoxDecoration(
                            color: SongListStyleConfig.vipBackgroundColor,
                            borderRadius: BorderRadius.circular(
                              SongListLayoutConfig.vipRadius,
                            ),
                          ),
                          child: const Text(
                            'VIP',
                            style: SongListStyleConfig.vipTextStyle,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: SongListLayoutConfig.spacingSmall),

                  // 艺术家和专辑
                  Text(
                    '${track.artistNames} • ${track.album.name}',
                    style: SongListStyleConfig.getArtistAlbumStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 更多操作
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: SongListStyleConfig.getMoreIconColor(context),
              ),
              onPressed: () => _onMoreTap(track, index),
              tooltip: '更多操作',
            ),
          ],
        ),
      ),
    );
  }

  /// 点击歌曲事件处理
  void _onTrackTap(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context, listen: false);

    // 设置播放列表和当前歌曲
    playerService.setPlaylist(_recommendedSongs, index);
    playerService.play();
  }

  /// 更多操作处理
  void _onMoreTap(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    
    SongDetailPanel.show(
      context: context,
      track: track,
      index: index,
      onPlay: () {
        // 播放当前歌曲
        playerService.setPlaylist(_recommendedSongs, index);
        playerService.play();
      },
    );
  }

  /// 导航到推荐歌曲页面
  void _navigateToRecommendPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RecommendSongsPage(recommendedSongs: _recommendedSongs),
      ),
    );
  }

  /// 构建推荐歌单部分
  Widget _buildRecommendedPlaylistsSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '推荐歌单',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                if (_recommendedPlaylists.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // 推荐歌单列表
          _isPlaylistLoading
              ? _buildPlaylistLoadingWidget()
              : _recommendedPlaylists.isEmpty
              ? _buildPlaylistEmptyWidget()
              : _buildPlaylistsGrid(),
        ],
      ),
    );
  }

  /// 构建歌单加载中组件
  Widget _buildPlaylistLoadingWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载推荐歌单...'),
          ],
        ),
      ),
    );
  }

  /// 构建歌单空状态组件
  Widget _buildPlaylistEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.queue_music, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '暂无推荐歌单',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '请检查网络连接或稍后重试',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendedPlaylists,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建歌单网格
  Widget _buildPlaylistsGrid() {
    // 只显示前6个歌单作为预览
    final displayPlaylists = _recommendedPlaylists.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75, // 调整比例，给文字更多空间
        ),
        itemCount: displayPlaylists.length,
        itemBuilder: (context, index) {
          return _buildPlaylistItem(displayPlaylists[index]);
        },
      ),
    );
  }

  /// 构建单个歌单项
  Widget _buildPlaylistItem(RecommendedPlaylist playlist) {
    return InkWell(
      onTap: () => _onPlaylistTap(playlist),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歌单封面
          Expanded(
            flex: 4, // 给图片更多空间
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // 背景图片
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: Image.network(
                      '${playlist.picUrl}?param=300y300',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                  // 播放次数标签
                  if (playlist.playcount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              playlist.formattedPlaycount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 标签（如果有）
                  if (playlist.copywriter.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          playlist.copywriter,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // 歌单信息区域
          Expanded(
            flex: 2, // 给文字更多空间
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 歌单名称
                  Text(
                    playlist.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3, // 增加行高
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 歌单点击事件处理
  void _onPlaylistTap(RecommendedPlaylist playlist) {
    // 跳转到歌单详情页面
    Navigator.pushNamed(
      context,
      '/playlist_detail',
      arguments: {
        'playlistId': playlist.id.toString(),
        'playlistName': playlist.name,
      },
    );
    AppLogger.info('跳转到歌单详情: ${playlist.name} (ID: ${playlist.id})');
  }
}
