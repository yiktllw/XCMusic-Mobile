import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../models/playlist.dart';
import '../pages/player_page.dart';
import '../widgets/playlist_sheet.dart';

/// 全局浮动播放栏组件
/// 可以在任何需要的页面中轻松集成
class FloatingPlayerBar extends StatelessWidget {
  /// 是否自动适应安全区域
  final bool adaptSafeArea;
  
  /// 距离底部的额外间距
  final double bottomOffset;
  
  /// 左右间距
  final double horizontalPadding;
  
  const FloatingPlayerBar({
    super.key,
    this.adaptSafeArea = true,
    this.bottomOffset = 20,
    this.horizontalPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: adaptSafeArea 
          ? MediaQuery.of(context).padding.bottom + bottomOffset
          : bottomOffset,
      child: Consumer<PlayerService>(
        builder: (context, playerService, child) {
          final currentTrack = playerService.currentTrack;
          // 只有在有当前播放歌曲时才显示浮动控件
          if (currentTrack == null) {
            return const SizedBox.shrink();
          }
          return _buildPlayerBar(context, playerService, currentTrack);
        },
      ),
    );
  }

  /// 构建播放栏UI
  Widget _buildPlayerBar(
    BuildContext context,
    PlayerService playerService,
    Track currentTrack,
  ) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPlayerPage(context),
        child: Row(
          children: [
            // 歌曲信息区域
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
                child: Row(
                  children: [
                    // 专辑封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: currentTrack.album.picUrl.isNotEmpty
                            ? Image.network(
                                '${currentTrack.album.picUrl}?param=100y100',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.music_note,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.music_note,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 歌曲信息
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentTrack.artists.isNotEmpty)
                            Text(
                              '${currentTrack.artists.map((artist) => artist.name).join(', ')} · ${currentTrack.album.name}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
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
            ),
            // 播放控制区域
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => playerService.playPause(),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showPlaylist(context, playerService, currentTrack),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.playlist_play,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 打开播放器页面
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
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: const PlayerPage(),
        ),
      ),
    );
  }

  /// 显示播放列表
  void _showPlaylist(BuildContext context, PlayerService playerService, Track? currentTrack) {
    PlaylistSheet.show(context, currentTrack);
  }
}

/// 为页面内容提供底部适当空间的Wrapper组件
class FloatingPlayerBarAware extends StatelessWidget {
  final Widget child;
  final bool adaptSafeArea;
  final double bottomSpace;

  const FloatingPlayerBarAware({
    super.key,
    required this.child,
    this.adaptSafeArea = true,
    this.bottomSpace = 100, // 默认为播放栏高度 + 间距
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = adaptSafeArea 
        ? MediaQuery.of(context).padding.bottom + bottomSpace
        : bottomSpace;
        
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: child,
    );
  }
}

/// 提供完整页面布局的Scaffold封装
/// 自动包含浮动播放栏和适当的内容间距
class PageWithFloatingPlayer extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  
  /// 是否显示浮动播放栏
  final bool showFloatingPlayer;
  
  /// 浮动播放栏配置
  final bool adaptSafeArea;
  final double playerBottomOffset;
  final double playerHorizontalPadding;

  const PageWithFloatingPlayer({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.showFloatingPlayer = true,
    this.adaptSafeArea = true,
    this.playerBottomOffset = 20,
    this.playerHorizontalPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: showFloatingPlayer
          ? Stack(
              children: [
                body,
                FloatingPlayerBar(
                  adaptSafeArea: adaptSafeArea,
                  bottomOffset: playerBottomOffset,
                  horizontalPadding: playerHorizontalPadding,
                ),
              ],
            )
          : body,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}
