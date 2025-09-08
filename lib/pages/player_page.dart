import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../services/likelist_service.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/scrolling_text.dart';
import '../widgets/song_detail_panel.dart';

/// 播放界面
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _albumRotationController;
  late Animation<double> _albumRotationAnimation;
  double? _statusBarHeight; // 缓存状态栏高度

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addObserver(this);
    
    // 在下一帧时计算状态栏高度（确保MediaQuery可用）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getStatusBarHeight(context);
      }
    });
  }

  void _initAnimations() {
    _albumRotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _albumRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_albumRotationController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _albumRotationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用进入后台时暂停动画，回到前台时根据播放状态恢复
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // 应用进入后台，暂停动画
      if (_albumRotationController.isAnimating) {
        _albumRotationController.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 应用回到前台，根据播放状态决定是否恢复动画
      final playerService = Provider.of<PlayerService>(context, listen: false);
      if (playerService.isPlaying && !_albumRotationController.isAnimating) {
        _albumRotationController.repeat();
      }
    }
  }

  /// 获取状态栏高度（带缓存）
  double _getStatusBarHeight(BuildContext context) {
    // 如果已经缓存，直接返回
    if (_statusBarHeight != null) {
      return _statusBarHeight!;
    }

    // 首先尝试从 MediaQuery 获取
    final mediaQueryPadding = MediaQuery.of(context).padding.top;
    if (mediaQueryPadding > 0) {
      AppLogger.info('MediaQuery padding: $mediaQueryPadding');
      _statusBarHeight = mediaQueryPadding;
      return _statusBarHeight!;
    }
    
    // 如果 MediaQuery 返回0，使用 View API
    final view = View.of(context);
    final statusBarHeight = view.padding.top / view.devicePixelRatio;
    if (statusBarHeight > 0) {
      AppLogger.info('View padding: $statusBarHeight');
      _statusBarHeight = statusBarHeight;
      return _statusBarHeight!;
    }
    
    // 最后的备用方案：使用固定高度
    AppLogger.warning('无法获取状态栏高度，使用默认值');
    _statusBarHeight = 44.0; // iOS刘海屏的标准状态栏高度
    return _statusBarHeight!;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, playerService, child) {
        final currentTrack = playerService.currentTrack;
        
        // 控制唱片旋转动画
        if (playerService.isPlaying && !_albumRotationController.isAnimating) {
          _albumRotationController.repeat();
        } else if (!playerService.isPlaying && _albumRotationController.isAnimating) {
          _albumRotationController.stop();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // 状态栏占位区域 - 使用多种方法获取状态栏高度
              Container(
                height: _getStatusBarHeight(context),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              // 自定义顶部栏
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      iconSize: 28,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // 播放器内容
              Expanded(
                child: currentTrack != null ? _buildPlayerContent(context, playerService, currentTrack) : _buildEmptyState(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerContent(BuildContext context, PlayerService playerService, Track track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算底部控制区域的大概高度
        final bottomControlsHeight = 300.0; // 底部控制区域的大概高度
        
        // 计算专辑封面可用的空间
        final availableHeight = constraints.maxHeight;
        final albumCoverSpace = availableHeight - bottomControlsHeight;
        
        // 根据可用空间决定显示方式
        final shouldShowFullAlbumCover = albumCoverSpace >= 150;
        final shouldShowMiniAlbumCover = albumCoverSpace >= 60;
        
        return Column(
          children: [
            // 专辑封面区域 - 根据空间大小显示不同版本
            if (shouldShowFullAlbumCover)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: _buildAlbumCover(track),
                  ),
                ),
              )
            else if (shouldShowMiniAlbumCover)
              // 空间较小时显示迷你封面
              SizedBox(
                height: albumCoverSpace.clamp(60.0, 120.0),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: ClipOval(
                        child: Image.network(
                          '${track.album.picUrl}?param=200y200',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.music_note,
                                size: 24,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              // 空间极小时显示图标
              SizedBox(
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.music_note,
                    size: 24,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            
            // 底部控制区域 - 固定在屏幕下方，适应安全区域
            Container(
              padding: EdgeInsets.fromLTRB(0, 16.0, 0, 24.0 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 歌曲信息
                  _buildSongInfo(track),
                  
                  const SizedBox(height: 16),
                  
                  // 进度条
                  _buildProgressBar(playerService),
                  
                  const SizedBox(height: 16),
                  
                  // 播放控件
                  _buildPlayControls(playerService),
                  
                  const SizedBox(height: 8),
                  
                  // 额外控制栏（喜欢、评论、收藏、下载、详情按钮）
                  _buildAdditionalControls(context, track),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlbumCover(Track track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算可用的最大尺寸，保持正方形
        final maxSize = constraints.biggest.shortestSide;
        // 留出一些边距，避免贴边，但不强制最小尺寸
        final albumSize = maxSize * 0.9;
        final coverSize = albumSize * 0.625; // 专辑封面占黑胶的62.5%
        
        return AnimatedBuilder(
          animation: _albumRotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _albumRotationAnimation.value * 2 * 3.14159,
              child: SizedBox(
                width: albumSize,
                height: albumSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 黑胶外圈 - 使用PNG
                    Container(
                      width: albumSize,
                      height: albumSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, // 设置为圆形
                        boxShadow: [
                          // 主要外阴影 - 居中，无偏移
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 0), // 无偏移，阴影均匀分布
                            spreadRadius: 2,
                          ),
                          // 轻微的向下阴影，增加立体感
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        child: Image.asset(
                          'assets/images/vinyl_ring_2x.png', // 使用PNG版本提升性能
                          width: albumSize,
                          height: albumSize,
                          filterQuality: FilterQuality.medium, // 优化缩放质量
                        ),
                      ),
                    ),
                    // 专辑封面
                    Container(
                      width: coverSize,
                      height: coverSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          '${track.album.picUrl}?param=500y500',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.music_note,
                                size: coverSize * 0.4, // 图标大小随封面大小缩放
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 中心圆点（唱片轴心）
                    Container(
                      width: albumSize * 0.0375, // 相对于黑胶大小的比例
                      height: albumSize * 0.0375,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black87,
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongInfo(Track track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // 歌曲名（一行，可滚动）
          ScrollingText(
            text: track.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 歌手和专辑在同一行（可滚动）
          ScrollingText(
            text: '${track.artistNames} · ${track.album.name}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlayerService playerService) {
    // 安全地计算进度值
    double progress = 0.0;
    if (playerService.duration.inMilliseconds > 0) {
      progress = (playerService.position.inMilliseconds / playerService.duration.inMilliseconds)
          .clamp(0.0, 1.0);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * playerService.duration.inMilliseconds).round(),
                );
                playerService.seek(newPosition);
              },
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          // 时间显示与滑块左右边缘对齐
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24), // 使用24px来匹配Slider的内部padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(playerService.position),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                Text(
                  _formatDuration(playerService.duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayControls(PlayerService playerService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 播放模式
          IconButton(
            icon: Icon(_getPlayModeIcon(playerService.playMode)),
            iconSize: 28,
            onPressed: () => _togglePlayMode(playerService),
            tooltip: _getPlayModeTooltip(playerService.playMode),
          ),
          
          // 上一首
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 36,
            onPressed: playerService.hasPrevious ? () => playerService.previous() : null,
          ),
          
          // 播放/暂停
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              iconSize: 36,
              onPressed: () => playerService.playPause(),
            ),
          ),
          
          // 下一首
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 36,
            onPressed: playerService.hasNext ? () => playerService.next() : null,
          ),
          
          // 播放列表
          IconButton(
            icon: const Icon(Icons.queue_music),
            iconSize: 28,
            onPressed: () => _showPlaylist(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放歌曲',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.listLoop:
        return Icons.repeat;
      case PlayMode.singleLoop:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.listLoop:
        return '列表循环';
      case PlayMode.singleLoop:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }

  void _togglePlayMode(PlayerService playerService) {
    final currentMode = playerService.playMode;
    PlayMode newMode;
    
    switch (currentMode) {
      case PlayMode.listLoop:
        newMode = PlayMode.singleLoop;
        break;
      case PlayMode.singleLoop:
        newMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        newMode = PlayMode.listLoop;
        break;
    }
    
    playerService.setPlayMode(newMode);
  }

  void _showPlaylist(BuildContext context) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    PlaylistSheet.show(context, playerService.currentTrack);
  }



  String _formatDuration(Duration duration) {
    // 确保时间不为负数
    final safeDuration = Duration(milliseconds: duration.inMilliseconds.clamp(0, 86400000)); // 最大24小时
    final minutes = safeDuration.inMinutes;
    final seconds = safeDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 构建额外控制栏（喜欢、评论、收藏、下载、详情按钮）
  Widget _buildAdditionalControls(BuildContext context, Track track) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 喜欢按钮
          _buildHeartButton(track),
          
          // 评论按钮
          _buildCommentButton(context, track),
          
          // 收藏按钮
          _buildCollectButton(context, track),
          
          // 下载按钮
          _buildDownloadButton(context, track),
          
          // 歌曲详情按钮
          _buildSongDetailButton(context, track),
        ],
      ),
    );
  }

  /// 构建喜欢按钮
  Widget _buildHeartButton(Track track) {
    final likelistService = LikelistService();
    final isLiked = likelistService.isLikedSong(track.id);
    
    return IconButton(
      icon: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? Colors.red : null, // 未喜欢时使用默认颜色
        size: 28,
      ),
      onPressed: () {
        // 功能暂不实装，只是显示当前状态
        // TODO: 实现喜欢/取消喜欢功能
      },
      tooltip: isLiked ? '已喜欢' : '喜欢',
    );
  }

  /// 构建歌曲详情按钮
  Widget _buildSongDetailButton(BuildContext context, Track track) {
    return IconButton(
      icon: Icon(
        Icons.info_outline,
        size: 28,
      ),
      onPressed: () {
        SongDetailPanel.show(
          context: context,
          track: track,
          index: 0, // 播放器页面中当前歌曲索引设为0
        );
      },
      tooltip: '歌曲详情',
    );
  }

  /// 构建评论按钮
  Widget _buildCommentButton(BuildContext context, Track track) {
    return IconButton(
      icon: Icon(
        Icons.comment_outlined,
        size: 28,
      ),
      onPressed: () {
        // TODO: 实现评论功能
      },
      tooltip: '评论',
    );
  }

  /// 构建收藏按钮
  Widget _buildCollectButton(BuildContext context, Track track) {
    return IconButton(
      icon: Icon(
        Icons.playlist_add,
        size: 28,
      ),
      onPressed: () {
        // TODO: 实现收藏到歌单功能
      },
      tooltip: '收藏',
    );
  }

  /// 构建下载按钮
  Widget _buildDownloadButton(BuildContext context, Track track) {
    return IconButton(
      icon: Icon(
        Icons.download_outlined,
        size: 28,
      ),
      onPressed: () {
        // TODO: 实现下载功能
      },
      tooltip: '下载',
    );
  }
}
