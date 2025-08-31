import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addObserver(this);
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
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
                  ? Brightness.light 
                  : Brightness.dark,
              statusBarBrightness: Theme.of(context).brightness,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showMoreOptions(context, playerService),
              ),
            ],
          ),
          body: SafeArea(
            child: currentTrack != null ? _buildPlayerContent(context, playerService, currentTrack) : _buildEmptyState(),
          ),
        );
      },
    );
  }

  Widget _buildPlayerContent(BuildContext context, PlayerService playerService, Track track) {
    return Column(
      children: [
        // 专辑封面区域 - 在剩余空间中居中
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: _buildAlbumCover(track),
            ),
          ),
        ),
        
        // 底部控制区域 - 固定在屏幕下方
        Container(
          padding: const EdgeInsets.fromLTRB(0, 16.0, 0, 24.0),
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
  }

  Widget _buildAlbumCover(Track track) {
    return AnimatedBuilder(
      animation: _albumRotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _albumRotationAnimation.value * 2 * 3.14159,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 黑胶外圈 - 使用PNG
              Container(
                width: 320,
                height: 320,
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
                    width: 320,
                    height: 320,
                    filterQuality: FilterQuality.medium, // 优化缩放质量
                  ),
                ),
              ),
              // 专辑封面
              Container(
                width: 200,
                height: 200,
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
                          size: 80,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // 中心圆点（唱片轴心）
              Container(
                width: 12,
                height: 12,
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

  void _showMoreOptions(BuildContext context, PlayerService playerService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('播放列表'),
              onTap: () {
                Navigator.pop(context);
                _showPlaylist(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现分享功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现收藏功能
              },
            ),
          ],
        ),
      ),
    );
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
    return Container(
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
