import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';

/// 虚拟滚动歌曲列表组件
class VirtualSongList extends StatefulWidget {
  /// 歌曲列表
  final List<Track> tracks;
  
  /// 歌曲点击回调
  final Function(Track track, int index)? onTrackTap;
  
  /// 播放按钮点击回调
  final Function(Track track, int index)? onPlayTap;
  
  /// 更多操作回调
  final Function(Track track, int index)? onMoreTap;
  
  /// 当前播放的歌曲ID
  final int? currentPlayingId;
  
  /// 是否显示序号
  final bool showIndex;
  
  /// 列表项高度
  final double itemHeight;
  
  /// 是否启用搜索
  final bool enableSearch;
  
  /// 搜索提示文本
  final String searchHint;
  
  /// 头部内容构建器
  final Widget Function()? headerBuilder;
  
  /// 头部高度
  final double headerHeight;

  const VirtualSongList({
    super.key,
    required this.tracks,
    this.onTrackTap,
    this.onPlayTap,
    this.onMoreTap,
    this.currentPlayingId,
    this.showIndex = true,
    this.itemHeight = 72.0,
    this.enableSearch = true,
    this.searchHint = '搜索歌曲、歌手、专辑',
    this.headerBuilder,
    this.headerHeight = 0.0,
  });

  @override
  State<VirtualSongList> createState() => _VirtualSongListState();
}

class _VirtualSongListState extends State<VirtualSongList> {
  final ScrollController _scrollController = ScrollController();
  List<Track> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _filteredTracks = widget.tracks;
  }

  @override
  void didUpdateWidget(VirtualSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks) {
      setState(() {
        _filteredTracks = widget.tracks;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 定位到指定歌曲ID
  void scrollToTrack(int trackId) {
    final index = _filteredTracks.indexWhere((track) => track.id == trackId);
    if (index != -1) {
      final targetOffset = widget.headerHeight + (index * widget.itemHeight);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filteredTracks.isEmpty) {
      return _buildEmptyState();
    }

    // 如果有头部内容，使用CustomScrollView
    if (widget.headerBuilder != null) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 头部内容
          SliverToBoxAdapter(
            child: widget.headerBuilder!(),
          ),
          
          // 歌曲列表
          SliverList.builder(
            itemCount: _filteredTracks.length,
            itemBuilder: (context, index) {
              final track = _filteredTracks[index];
              final originalIndex = widget.tracks.indexOf(track);
              return SizedBox(
                height: widget.itemHeight,
                child: _buildTrackItem(track, originalIndex, index),
              );
            },
          ),
        ],
      );
    }

    // 没有头部内容时使用普通ListView
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredTracks.length,
      itemExtent: widget.itemHeight,
      itemBuilder: (context, index) {
        final track = _filteredTracks[index];
        final originalIndex = widget.tracks.indexOf(track);
        return _buildTrackItem(track, originalIndex, index);
      },
    );
  }

  /// 构建空状态
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
            '暂无歌曲',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  /// 构建歌曲项
  Widget _buildTrackItem(Track track, int originalIndex, int displayIndex) {
    final isCurrentPlaying = track.id == widget.currentPlayingId;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        // 默认行为：播放歌曲
        if (widget.onTrackTap != null) {
          widget.onTrackTap?.call(track, originalIndex);
        } else {
          // 如果没有自定义点击处理，使用PlayerService播放
          final playerService = Provider.of<PlayerService>(context, listen: false);
          playerService.setPlaylist(widget.tracks, originalIndex);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // 序号或播放状态
            SizedBox(
              width: 30,
              child: widget.showIndex
                  ? isCurrentPlaying
                      ? Icon(
                          Icons.volume_up,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      : Text(
                          '${originalIndex + 1}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        )
                  : const SizedBox(),
            ),
            
            const SizedBox(width: 12),
            
            // 歌曲封面
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                "${track.album.picUrl}?param=100y100",
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 48,
                    height: 48,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note,
                      color: theme.colorScheme.outline,
                      size: 24,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 歌曲名
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isCurrentPlaying
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: isCurrentPlaying
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // VIP标识
                      if (track.isVip) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // 艺术家和专辑
                  Text(
                    '${track.artistNames} • ${track.album.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                color: theme.colorScheme.outline,
              ),
              onPressed: () => widget.onMoreTap?.call(track, originalIndex),
              tooltip: '更多操作',
            ),
          ],
        ),
      ),
    );
  }
}

/// 虚拟滚动歌曲列表控制器
class VirtualSongListController {
  _VirtualSongListState? _state;

  void _attach(_VirtualSongListState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// 定位到指定歌曲
  void scrollToTrack(int trackId) {
    _state?.scrollToTrack(trackId);
  }
}

/// 带控制器的虚拟滚动歌曲列表
class VirtualSongListWithController extends StatefulWidget {
  final VirtualSongListController? controller;
  final List<Track> tracks;
  final Function(Track track, int index)? onTrackTap;
  final Function(Track track, int index)? onPlayTap;
  final Function(Track track, int index)? onMoreTap;
  final int? currentPlayingId;
  final bool showIndex;
  final double itemHeight;
  final bool enableSearch;
  final String searchHint;
  final Widget Function()? headerBuilder;
  final double headerHeight;

  const VirtualSongListWithController({
    super.key,
    this.controller,
    required this.tracks,
    this.onTrackTap,
    this.onPlayTap,
    this.onMoreTap,
    this.currentPlayingId,
    this.showIndex = true,
    this.itemHeight = 72.0,
    this.enableSearch = true,
    this.searchHint = '搜索歌曲、歌手、专辑',
    this.headerBuilder,
    this.headerHeight = 0.0,
  });

  @override
  State<VirtualSongListWithController> createState() =>
      _VirtualSongListWithControllerState();
}

class _VirtualSongListWithControllerState
    extends State<VirtualSongListWithController> {
  final GlobalKey<_VirtualSongListState> _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listKey.currentState != null) {
        widget.controller?._attach(_listKey.currentState!);
      }
    });
  }

  @override
  void didUpdateWidget(VirtualSongListWithController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      if (_listKey.currentState != null) {
        widget.controller?._attach(_listKey.currentState!);
      }
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VirtualSongList(
      key: _listKey,
      tracks: widget.tracks,
      onTrackTap: widget.onTrackTap,
      onPlayTap: widget.onPlayTap,
      onMoreTap: widget.onMoreTap,
      currentPlayingId: widget.currentPlayingId,
      showIndex: widget.showIndex,
      itemHeight: widget.itemHeight,
      enableSearch: widget.enableSearch,
      searchHint: widget.searchHint,
      headerBuilder: widget.headerBuilder,
      headerHeight: widget.headerHeight,
    );
  }
}
