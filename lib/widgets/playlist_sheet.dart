import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../config/song_list_layout.dart';

/// 播放列表底部表单组件
class PlaylistSheet extends StatelessWidget {
  final Track? currentTrack;
  final ScrollController? scrollController;

  const PlaylistSheet({
    super.key,
    this.currentTrack,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, playerService, child) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '播放列表',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${playerService.playlist.length}首',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      // 清空按钮
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: playerService.playlist.isNotEmpty
                            ? () => _showClearDialog(context, playerService)
                            : null,
                        tooltip: '清空播放列表',
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // 播放列表内容
                Expanded(
                  child: playerService.playlist.isEmpty
                      ? _buildEmptyState(context)
                      : _buildPlaylist(context, playerService, scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '播放列表为空',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建播放列表
  Widget _buildPlaylist(BuildContext context, PlayerService playerService, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      itemCount: playerService.playlist.length,
      itemBuilder: (context, index) {
        final track = playerService.playlist[index];
        final isCurrentTrack = currentTrack != null && track.id == currentTrack!.id;

        return _buildPlaylistItem(context, track, index, isCurrentTrack, playerService);
      },
    );
  }

  /// 构建播放列表项
  Widget _buildPlaylistItem(BuildContext context, Track track, int index, bool isCurrentTrack, PlayerService playerService) {
    return InkWell(
      onTap: () {
        playerService.playTrackAt(index);
      },
      child: Padding(
        padding: SongListLayoutConfig.itemPadding,
        child: Row(
          children: [
            // 序号或播放状态
            SizedBox(
              width: SongListLayoutConfig.indexWidth,
              child: isCurrentTrack
                  ? Icon(
                      Icons.volume_up,
                      color: SongListStyleConfig.getPlayingIconColor(context),
                      size: SongListLayoutConfig.playingIconSize,
                    )
                  : Text(
                      '${index + 1}',
                      style: SongListStyleConfig.getIndexStyle(context),
                      textAlign: TextAlign.center,
                    ),
            ),
            
            const SizedBox(width: SongListLayoutConfig.spacingMedium),
            
            // 专辑封面
            ClipRRect(
              borderRadius: BorderRadius.circular(SongListLayoutConfig.albumCoverRadius),
              child: SizedBox(
                width: SongListLayoutConfig.albumCoverSize,
                height: SongListLayoutConfig.albumCoverSize,
                child: track.album.picUrl.isNotEmpty
                    ? Image.network(
                        "${track.album.picUrl}${SongListLayoutConfig.albumCoverParam}",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: SongListStyleConfig.getErrorBackgroundColor(context),
                            child: Icon(
                              Icons.music_note,
                              color: SongListStyleConfig.getErrorIconColor(context),
                              size: SongListLayoutConfig.errorIconSize,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: SongListStyleConfig.getErrorBackgroundColor(context),
                        child: Icon(
                          Icons.music_note,
                          color: SongListStyleConfig.getErrorIconColor(context),
                          size: SongListLayoutConfig.errorIconSize,
                        ),
                      ),
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
                            isCurrentPlaying: isCurrentTrack,
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
                            borderRadius: BorderRadius.circular(SongListLayoutConfig.vipRadius),
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
                  
                  // 艺术家
                  if (track.artists.isNotEmpty)
                    Text(
                      track.artists.map((artist) => artist.name).join(', '),
                      style: SongListStyleConfig.getArtistAlbumStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // 移除按钮
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: SongListStyleConfig.getMoreIconColor(context),
              onPressed: () {
                playerService.removeFromPlaylist(index);
              },
              tooltip: '从播放列表移除',
            ),
          ],
        ),
      ),
    );
  }

  /// 显示清空确认对话框
  void _showClearDialog(BuildContext context, PlayerService playerService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空所有歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              playerService.clearPlaylist();
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(context); // 关闭播放列表
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示播放列表底部表单
  static void show(BuildContext context, Track? currentTrack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaylistSheet(currentTrack: currentTrack),
    );
  }
}
