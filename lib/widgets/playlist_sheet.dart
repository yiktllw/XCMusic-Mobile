import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';

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

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 42,
              height: 42,
              child: track.album.picUrl.isNotEmpty
                  ? Image.network(
                      track.album.picUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isCurrentTrack
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.music_note,
                            color: isCurrentTrack
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: isCurrentTrack
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        color: isCurrentTrack
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          title: Text(
            track.name,
            style: TextStyle(
              color: isCurrentTrack
                  ? Theme.of(context).colorScheme.primary
                  : null,
              fontWeight: isCurrentTrack ? FontWeight.w500 : null,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: track.artists.isNotEmpty
              ? Text(
                  track.artists.map((artist) => artist.name).join(', '),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              playerService.removeFromPlaylist(index);
            },
            tooltip: '从播放列表中移除',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
          ),
          onTap: () {
            playerService.playTrackAt(index);
            Navigator.pop(context);
          },
        );
      },
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
