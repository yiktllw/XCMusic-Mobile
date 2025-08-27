import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';
import '../utils/top_banner.dart';

/// 底部播放栏组件
class BottomPlayerBar extends StatelessWidget {
  const BottomPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, playerService, child) {
        final currentTrack = playerService.currentTrack;
        
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _openPlayerPage(context),
            child: Row(
              children: [
                // 专辑封面
                _buildAlbumCover(context, currentTrack),
                
                // 歌曲信息
                Expanded(
                  child: _buildSongInfo(context, currentTrack),
                ),
                
                // 播放控件
                _buildPlayControls(context, playerService),
                
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumCover(BuildContext context, Track? track) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track != null 
            ? Image.network(
                track.album.picUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note,
                      size: 24,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  );
                },
              )
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note,
                  size: 24,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, Track? track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track?.name ?? '暂无播放歌曲',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            track?.artistNames ?? '点击播放音乐',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayControls(BuildContext context, PlayerService playerService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 播放/暂停按钮
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: IconButton(
            icon: Icon(
              playerService.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).colorScheme.primary,
            ),
            iconSize: 20,
            onPressed: () => playerService.playPause(),
            padding: EdgeInsets.zero,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 下一首按钮
        IconButton(
          icon: Icon(
            Icons.skip_next,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          iconSize: 24,
          onPressed: playerService.hasNext ? () => playerService.next() : null,
          padding: EdgeInsets.zero,
        ),
        
        const SizedBox(width: 4),
        
        // 播放列表按钮
        IconButton(
          icon: Icon(
            Icons.queue_music,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          iconSize: 24,
          onPressed: () => _showPlaylistPanel(context),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  void _openPlayerPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: PlayerPage(),
        ),
      ),
    );
  }

  void _showPlaylistPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlaylistPanel(),
    );
  }
}

/// 播放列表面板
class PlaylistPanel extends StatelessWidget {
  const PlaylistPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Consumer<PlayerService>(
        builder: (context, playerService, child) {
          return Column(
            children: [
              // 顶部拖拽指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 头部信息
              _buildHeader(context, playerService),
              
              // 播放列表
              Expanded(
                child: _buildPlaylist(context, playerService),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PlayerService playerService) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            '当前播放',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${playerService.playlist.length})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const Spacer(),
          
          // 播放模式
          IconButton(
            icon: Icon(_getPlayModeIcon(playerService.playMode)),
            onPressed: () => _togglePlayMode(context, playerService),
            tooltip: _getPlayModeTooltip(playerService.playMode),
          ),
          
          // 清空列表
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: playerService.playlist.isNotEmpty 
                ? () => _showClearDialog(context, playerService)
                : null,
            tooltip: '清空播放列表',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(BuildContext context, PlayerService playerService) {
    if (playerService.playlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '播放列表为空',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: playerService.playlist.length,
      itemBuilder: (context, index) {
        final track = playerService.playlist[index];
        final isCurrentTrack = playerService.currentIndex == index;
        
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                track.album.picUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note,
                      size: 20,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  );
                },
              ),
            ),
          ),
          title: Text(
            track.name,
            style: TextStyle(
              color: isCurrentTrack 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artistNames,
            style: TextStyle(
              color: isCurrentTrack 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isCurrentTrack
              ? Icon(
                  Icons.volume_up,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                )
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => playerService.removeFromPlaylist(index),
                  tooltip: '从播放列表移除',
                ),
          onTap: () {
            if (!isCurrentTrack) {
              playerService.playTrackAt(index);
            }
            Navigator.pop(context);
          },
        );
      },
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

  void _togglePlayMode(BuildContext context, PlayerService playerService) {
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
    
    TopBanner.showInfo(
      context,
      '切换到${_getPlayModeTooltip(newMode)}',
      duration: const Duration(seconds: 1),
    );
  }

  void _showClearDialog(BuildContext context, PlayerService playerService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空当前播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              playerService.clearPlaylist();
              Navigator.pop(context);
              Navigator.pop(context); // 关闭播放列表面板
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
