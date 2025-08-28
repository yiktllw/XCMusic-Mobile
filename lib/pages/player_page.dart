import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../widgets/playlist_sheet.dart';

/// 播放界面
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with TickerProviderStateMixin {
  late AnimationController _albumRotationController;
  late Animation<double> _albumRotationAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
    _albumRotationController.dispose();
    super.dispose();
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32.0, 20.0, 32.0, 32.0),
            child: Column(
              children: [
                // 专辑封面
                Expanded(
                  flex: 3,
                  child: Center(
                    child: _buildAlbumCover(track),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 歌曲信息
                _buildSongInfo(track),
                
                const SizedBox(height: 24),
                
                // 进度条
                _buildProgressBar(playerService),
                
                const SizedBox(height: 32),
                
                // 播放控件
                _buildPlayControls(playerService),
              ],
            ),
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
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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
                      size: 100,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongInfo(Track track) {
    return Column(
      children: [
        Text(
          track.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          track.artistNames,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          track.album.name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar(PlayerService playerService) {
    // 安全地计算进度值
    double progress = 0.0;
    if (playerService.duration.inMilliseconds > 0) {
      progress = (playerService.position.inMilliseconds / playerService.duration.inMilliseconds)
          .clamp(0.0, 1.0);
    }
    
    return Column(
      children: [
        Slider(
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }

  Widget _buildPlayControls(PlayerService playerService) {
    return Row(
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
}
