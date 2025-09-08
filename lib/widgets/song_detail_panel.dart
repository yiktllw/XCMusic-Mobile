import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../utils/top_banner.dart';

/// 歌曲详情面板 - 通用组件
class SongDetailPanel extends StatelessWidget {
  /// 歌曲信息
  final Track track;
  
  /// 歌曲在列表中的索引
  final int index;
  
  /// 立即播放回调
  final VoidCallback? onPlay;
  
  /// 下一首播放回调
  final VoidCallback? onPlayNext;
  
  /// 歌手点击回调
  final VoidCallback? onArtistTap;
  
  /// 专辑点击回调
  final VoidCallback? onAlbumTap;
  
  /// 查看评论回调
  final VoidCallback? onCommentTap;
  
  /// 查看歌曲信息回调
  final VoidCallback? onSongInfoTap;
  
  /// 收藏回调
  final VoidCallback? onFavoriteTap;
  
  /// 下载回调
  final VoidCallback? onDownloadTap;
  
  /// 分享回调
  final VoidCallback? onShareTap;

  const SongDetailPanel({
    super.key,
    required this.track,
    required this.index,
    this.onPlay,
    this.onPlayNext,
    this.onArtistTap,
    this.onAlbumTap,
    this.onCommentTap,
    this.onSongInfoTap,
    this.onFavoriteTap,
    this.onDownloadTap,
    this.onShareTap,
  });

  /// 显示歌曲详情面板
  static void show({
    required BuildContext context,
    required Track track,
    required int index,
    VoidCallback? onPlay,
    VoidCallback? onPlayNext,
    VoidCallback? onArtistTap,
    VoidCallback? onAlbumTap,
    VoidCallback? onCommentTap,
    VoidCallback? onSongInfoTap,
    VoidCallback? onFavoriteTap,
    VoidCallback? onDownloadTap,
    VoidCallback? onShareTap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SongDetailPanel(
        track: track,
        index: index,
        onPlay: onPlay,
        onPlayNext: onPlayNext,
        onArtistTap: onArtistTap,
        onAlbumTap: onAlbumTap,
        onCommentTap: onCommentTap,
        onSongInfoTap: onSongInfoTap,
        onFavoriteTap: onFavoriteTap,
        onDownloadTap: onDownloadTap,
        onShareTap: onShareTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8; // 最大高度为屏幕高度的80%
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 可滚动内容区域
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 歌曲信息区域
                  _buildSongInfo(context),
                  
                  // 操作按钮区域
                  _buildActions(context),
                ],
              ),
            ),
          ),
          
          // 底部安全区域
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  /// 构建歌曲信息区域
  Widget _buildSongInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 封面图片
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    size: 24,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 歌曲名称
                Text(
                  track.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // 歌手信息
                Text(
                  track.artistNames,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 2),
                
                // 专辑信息
                Text(
                  track.album.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮区域
  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        
        // 立即播放
        _buildActionItem(
          context: context,
          icon: Icons.play_arrow,
          title: '立即播放',
          onTap: () {
            Navigator.pop(context);
            onPlay?.call();
          },
        ),
        
        // 下一首播放
        _buildActionItem(
          context: context,
          icon: Icons.queue_music,
          title: '下一首播放',
          onTap: () {
            Navigator.pop(context);
            onPlayNext?.call();
          },
        ),
        
        const Divider(height: 1),
        
        // 歌手
        _buildActionItem(
          context: context,
          icon: Icons.person,
          title: '歌手: ${track.artistNames}',
          onTap: () {
            Navigator.pop(context);
            if (onArtistTap != null) {
              onArtistTap!();
            } else {
              // TODO: 默认歌手页面跳转逻辑
              TopBanner.showInfo(
                context,
                '歌手页面功能开发中...',
              );
            }
          },
        ),
        
        // 专辑
        _buildActionItem(
          context: context,
          icon: Icons.album,
          title: '专辑: ${track.album.name}',
          onTap: () {
            Navigator.pop(context);
            onAlbumTap?.call();
          },
        ),
        
        // 查看评论
        _buildActionItem(
          context: context,
          icon: Icons.comment,
          title: '查看评论',
          onTap: () {
            Navigator.pop(context);
            if (onCommentTap != null) {
              onCommentTap!();
            } else {
              // TODO: 默认评论页面跳转逻辑
              TopBanner.showInfo(
                context,
                '评论功能开发中...',
              );
            }
          },
        ),
        
        // 查看歌曲信息
        _buildActionItem(
          context: context,
          icon: Icons.info_outline,
          title: '查看歌曲信息',
          onTap: () {
            Navigator.pop(context);
            if (onSongInfoTap != null) {
              onSongInfoTap!();
            } else {
              // 显示默认的歌曲信息对话框
              _showSongInfoDialog(context);
            }
          },
        ),
        
        const Divider(height: 1),
        
        // 收藏
        _buildActionItem(
          context: context,
          icon: Icons.favorite_border,
          title: '收藏',
          onTap: () {
            Navigator.pop(context);
            onFavoriteTap?.call();
          },
        ),
        
        // 下载
        _buildActionItem(
          context: context,
          icon: Icons.download,
          title: '下载',
          onTap: () {
            Navigator.pop(context);
            onDownloadTap?.call();
          },
        ),
        
        // 分享
        _buildActionItem(
          context: context,
          icon: Icons.share,
          title: '分享',
          onTap: () {
            Navigator.pop(context);
            onShareTap?.call();
          },
        ),
      ],
    );
  }

  /// 显示歌曲信息对话框
  void _showSongInfoDialog(BuildContext context) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在获取歌曲详情...'),
          ],
        ),
      ),
    );

    try {
      // 获取完整的歌曲详情
      final detailedTracks = await PlaylistService.getSongDetails([track.id]);
      Navigator.of(context).pop(); // 关闭加载对话框
      
      if (detailedTracks.isNotEmpty) {
        final detailedTrack = detailedTracks.first;
        _showDetailedSongInfoDialog(context, detailedTrack);
      } else {
        _showDetailedSongInfoDialog(context, track);
      }
    } catch (e) {
      Navigator.of(context).pop(); // 关闭加载对话框
      // 如果获取详情失败，使用原有数据
      _showDetailedSongInfoDialog(context, track);
    }
  }

  /// 显示详细的歌曲信息对话框
  void _showDetailedSongInfoDialog(BuildContext context, Track detailedTrack) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌曲信息'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // 歌曲ID
            _buildInfoRow(
              context: context,
              label: 'ID',
              value: detailedTrack.id.toString(),
            ),
            const SizedBox(height: 12),
            
            // 歌曲名
            _buildInfoRow(
              context: context,
              label: '歌曲',
              value: detailedTrack.name,
            ),
            
            // 歌曲译名 (如果有的话)
            if (detailedTrack.tns.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                context: context,
                label: '译名',
                value: detailedTrack.tns.first,
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 歌手(多个歌手分行显示)
            ...detailedTrack.artists.asMap().entries.map((entry) {
              final index = entry.key;
              final artist = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildInfoRow(
                  context: context,
                  label: index == 0 ? '歌手' : '', // 只有第一个歌手显示"歌手"标签
                  value: artist.name,
                ),
              );
            }),
            
            const SizedBox(height: 6),
            
            // 专辑
            _buildInfoRow(
              context: context,
              label: '专辑',
              value: detailedTrack.album.name,
            ),
            
            // 专辑译名 (如果有的话)
            if (detailedTrack.album.tns.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                context: context,
                label: '专辑译名',
                value: detailedTrack.album.tns.first,
              ),
            ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: label.isEmpty 
              ? const SizedBox() // 如果标签为空，则不显示任何内容
              : Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            TopBanner.showSuccess(context, '已复制到剪贴板');
          },
          icon: const Icon(Icons.copy, size: 16),
          constraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          padding: const EdgeInsets.all(2),
          tooltip: '复制',
        ),
      ],
    );
  }

  /// 构建操作项
  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      minVerticalPadding: 8,
      visualDensity: VisualDensity.compact,
    );
  }
}
