import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../services/player_service.dart';
import '../widgets/virtual_song_list.dart';
import '../utils/top_banner.dart';

/// 歌单详情页面
class PlaylistDetailPage extends StatefulWidget {
  /// 歌单ID
  final String playlistId;
  
  /// 歌单名称（可选，用于AppBar标题）
  final String? playlistName;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage>
    with TickerProviderStateMixin {
  PlaylistDetail? _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingMoreTracks = false;
  String? _error;
  int? _currentPlayingId;
  
  // 动画控制器
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  
  // 滚动控制器
  final ScrollController _scrollController = ScrollController();
  final VirtualSongListController _songListController = VirtualSongListController();
  
  // UI状态
  final double _expandedHeight = 300.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPlaylistDetail();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 初始化动画
  void _initAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  /// 加载歌单详情
  Future<void> _loadPlaylistDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final playlist = await PlaylistService.getPlaylistDetail(
        playlistId: widget.playlistId,
      );

      setState(() {
        _playlist = playlist;
        _tracks = playlist.tracks;
        _isLoading = false;
      });

      // 如果歌单歌曲数量大于当前加载的数量，尝试加载更多
      if (playlist.trackCount > playlist.tracks.length) {
        _loadMoreTracks();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 加载更多歌曲
  Future<void> _loadMoreTracks() async {
    if (_isLoadingMoreTracks || _playlist == null) return;

    try {
      setState(() {
        _isLoadingMoreTracks = true;
      });

      final moreTracks = await PlaylistService.getPlaylistTracks(
        playlistId: widget.playlistId,
        limit: 1000,
        offset: _tracks.length,
      );

      setState(() {
        _tracks.addAll(moreTracks);
        _isLoadingMoreTracks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreTracks = false;
      });
      if (mounted) {
        TopBanner.showError(
          context,
          '加载更多歌曲失败: ${e.toString()}',
        );
      }
    }
  }

  /// 歌曲点击处理
  void _onTrackTap(Track track, int index) {
    // 获取PlayerService并设置播放列表
    final playerService = Provider.of<PlayerService>(context, listen: false);
    
    // 设置播放列表为当前歌单的所有歌曲，并从点击的歌曲开始播放
    playerService.setPlaylist(_tracks, index);
    
    setState(() {
      _currentPlayingId = track.id;
    });
  }

  /// 播放按钮点击处理
  void _onPlayTap(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    
    if (_currentPlayingId == track.id && playerService.isPlaying) {
      // 当前正在播放，暂停
      playerService.pause();
      TopBanner.showInfo(
        context,
        '已暂停: ${track.name}',
      );
    } else {
      // 开始播放或恢复播放
      if (_currentPlayingId != track.id) {
        // 播放新歌曲
        playerService.setPlaylist(_tracks, index);
        setState(() {
          _currentPlayingId = track.id;
        });
      } else {
        // 恢复播放当前歌曲
        playerService.play();
      }
      
      TopBanner.showSuccess(
        context,
        '正在播放: ${track.name}',
      );
    }
  }

  /// 更多操作处理
  void _onMoreTap(Track track, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildTrackBottomSheet(track),
    );
  }

  /// 显示搜索功能
  void _showSearchDialog() {
    _songListController.showSearch();
  }

  /// 播放全部
  void _playAll() {
    if (_tracks.isNotEmpty) {
      // 获取PlayerService并设置播放列表
      final playerService = Provider.of<PlayerService>(context, listen: false);
      
      // 设置播放列表为当前歌单的所有歌曲，并从第一首开始播放
      playerService.setPlaylist(_tracks, 0);
      
      setState(() {
        _currentPlayingId = _tracks[0].id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPlaylistDetail,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 构建主要内容
  Widget _buildContent() {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _headerAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _headerAnimation.value,
              child: Text(
                _playlist?.name ?? widget.playlistName ?? '歌单',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: '搜索歌曲',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: VirtualSongListWithController(
        controller: _songListController,
        tracks: _tracks,
        onTrackTap: _onTrackTap,
        onPlayTap: _onPlayTap,
        onMoreTap: _onMoreTap,
        currentPlayingId: _currentPlayingId,
        searchHint: '在歌单中搜索',
        headerBuilder: _buildScrollableHeader,
        headerHeight: _expandedHeight,
      ),
    );
  }

  /// 构建可滚动的头部内容
  Widget _buildScrollableHeader() {
    if (_playlist == null) return SizedBox(height: _expandedHeight);

    return Container(
      height: _expandedHeight,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(_playlist!.coverImgUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.darken,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.only(
          top: kToolbarHeight + MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _playlist!.coverImgUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.music_note,
                          size: 40,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 歌单信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 歌单名称
                      Text(
                        _playlist!.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 创建者信息
                      Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              _playlist!.creator.avatarUrl,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 24,
                                  height: 24,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _playlist!.creator.nickname,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 统计信息
                      Text(
                        '${_playlist!.trackCount}首歌曲 • ${_formatPlayCount(_playlist!.playCount)}次播放',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 播放全部按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playAll,
                icon: const Icon(Icons.play_arrow),
                label: Text('播放全部 (${_tracks.length})'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建头部信息
  /// 构建歌曲底部操作面板
  Widget _buildTrackBottomSheet(Track track) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 歌曲信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    track.album.picUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.music_note),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artistNames,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 操作选项
          const Divider(),
          _buildBottomSheetItem(
            icon: Icons.play_arrow,
            title: '立即播放',
            onTap: () {
              Navigator.pop(context);
              _onPlayTap(track, _tracks.indexOf(track));
            },
          ),
          _buildBottomSheetItem(
            icon: Icons.queue_music,
            title: '下一首播放',
            onTap: () {
              Navigator.pop(context);
              // TODO: 添加到播放队列
            },
          ),
          _buildBottomSheetItem(
            icon: Icons.favorite_border,
            title: '收藏',
            onTap: () {
              Navigator.pop(context);
              // TODO: 收藏歌曲
            },
          ),
          _buildBottomSheetItem(
            icon: Icons.download,
            title: '下载',
            onTap: () {
              Navigator.pop(context);
              // TODO: 下载歌曲
            },
          ),
          _buildBottomSheetItem(
            icon: Icons.share,
            title: '分享',
            onTap: () {
              Navigator.pop(context);
              // TODO: 分享歌曲
            },
          ),
        ],
      ),
    );
  }

  /// 构建底部面板选项项
  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  /// 格式化播放次数
  String _formatPlayCount(int count) {
    if (count < 10000) {
      return count.toString();
    } else if (count < 100000000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
  }
}

/// 搜索对话框
class _SearchDialog extends StatefulWidget {
  final List<Track> tracks;
  final Function(Track) onTrackSelected;

  const _SearchDialog({
    required this.tracks,
    required this.onTrackSelected,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _filteredTracks = widget.tracks;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredTracks = widget.tracks;
      } else {
        _filteredTracks = widget.tracks.where((track) {
          return track.name.toLowerCase().contains(query) ||
              track.artistNames.toLowerCase().contains(query) ||
              track.album.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 搜索框
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索歌曲、歌手、专辑',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                filled: true,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 搜索结果
            Expanded(
              child: _filteredTracks.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty ? '请输入搜索关键词' : '没有找到相关歌曲',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTracks.length,
                      itemBuilder: (context, index) {
                        final track = _filteredTracks[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              track.album.picUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.music_note,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                );
                              },
                            ),
                          ),
                          title: Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artistNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onTrackSelected(track);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
