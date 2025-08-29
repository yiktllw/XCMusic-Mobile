import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../config/song_list_layout.dart';

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
    this.itemHeight = SongListLayoutConfig.itemHeight,
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
  final TextEditingController _searchController = TextEditingController();
  List<Track> _filteredTracks = [];
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _filteredTracks = widget.tracks;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(VirtualSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks) {
      setState(() {
        _filteredTracks = widget.tracks;
        _filterTracks();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索内容变化处理
  void _onSearchChanged() {
    _filterTracks();
  }

  /// 过滤歌曲列表
  void _filterTracks() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = widget.tracks;
      } else {
        _filteredTracks = widget.tracks.where((track) {
          // 搜索歌曲名、歌手、专辑（忽略大小写）
          final songName = track.name.toLowerCase();
          final artistNames = track.artistNames.toLowerCase();
          final albumName = track.album.name.toLowerCase();
          
          return songName.contains(query) ||
                 artistNames.contains(query) ||
                 albumName.contains(query);
        }).toList();
      }
    });
  }

  /// 切换搜索框显示状态
  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filteredTracks = widget.tracks;
      }
    });
  }

  /// 显示搜索框
  void _showSearch() {
    setState(() {
      _isSearchVisible = true;
    });
  }

  /// 隐藏搜索框
  void _hideSearch() {
    setState(() {
      _isSearchVisible = false;
      _searchController.clear();
      _filteredTracks = widget.tracks;
    });
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
    // 处理空状态
    if (_filteredTracks.isEmpty) {
      return Stack(
        children: [
          _buildEmptyState(),
          if (widget.enableSearch && _isSearchVisible) _buildFloatingSearchBar(),
        ],
      );
    }

    // 如果有头部内容，使用CustomScrollView
    if (widget.headerBuilder != null) {
      return Stack(
        children: [
          CustomScrollView(
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
              
              // 底部空白
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          if (widget.enableSearch && _isSearchVisible) _buildFloatingSearchBar(),
        ],
      );
    }

    // 没有头部内容时使用普通ListView
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          itemCount: _filteredTracks.length + 1, // 增加一个用于底部空白
          itemBuilder: (context, index) {
            // 如果是最后一个项目，返回底部空白
            if (index == _filteredTracks.length) {
              return const SizedBox(height: 80);
            }
            
            final track = _filteredTracks[index];
            final originalIndex = widget.tracks.indexOf(track);
            return SizedBox(
              height: widget.itemHeight,
              child: _buildTrackItem(track, originalIndex, index),
            );
          },
        ),
        if (widget.enableSearch && _isSearchVisible) _buildFloatingSearchBar(),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final hasSearchResults = _searchController.text.isNotEmpty && _filteredTracks.isEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearchResults ? Icons.search_off : Icons.music_note,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchResults ? '未找到相关歌曲' : '暂无歌曲',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (hasSearchResults) ...[
            const SizedBox(height: 8),
            Text(
              '试试其他关键词',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建浮动搜索框
  Widget _buildFloatingSearchBar() {
    return Positioned(
      top: 110, // 距离顶部80像素
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onChanged: (value) {
              setState(() {}); // 触发重建以更新suffixIcon
            },
          ),
        ),
      ),
    );
  }

  /// 构建歌曲项
  Widget _buildTrackItem(Track track, int originalIndex, int displayIndex) {
    final isCurrentPlaying = track.id == widget.currentPlayingId;
    
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
        padding: SongListLayoutConfig.itemPadding,
        child: Row(
          children: [
            // 序号或播放状态
            SizedBox(
              width: SongListLayoutConfig.indexWidth,
              child: widget.showIndex
                  ? isCurrentPlaying
                      ? Icon(
                          Icons.volume_up,
                          color: SongListStyleConfig.getPlayingIconColor(context),
                          size: SongListLayoutConfig.playingIconSize,
                        )
                      : Text(
                          '${originalIndex + 1}',
                          style: SongListStyleConfig.getIndexStyle(context),
                          textAlign: TextAlign.center,
                        )
                  : const SizedBox(),
            ),
            
            const SizedBox(width: SongListLayoutConfig.spacingMedium),
            
            // 歌曲封面
            ClipRRect(
              borderRadius: BorderRadius.circular(SongListLayoutConfig.albumCoverRadius),
              child: Image.network(
                "${track.album.picUrl}${SongListLayoutConfig.albumCoverParam}",
                width: SongListLayoutConfig.albumCoverSize,
                height: SongListLayoutConfig.albumCoverSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: SongListLayoutConfig.albumCoverSize,
                    height: SongListLayoutConfig.albumCoverSize,
                    color: SongListStyleConfig.getErrorBackgroundColor(context),
                    child: Icon(
                      Icons.music_note,
                      color: SongListStyleConfig.getErrorIconColor(context),
                      size: SongListLayoutConfig.errorIconSize,
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(width: SongListLayoutConfig.spacingMedium),
            
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
                          style: SongListStyleConfig.getSongNameStyle(
                            context,
                            isCurrentPlaying: isCurrentPlaying,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // VIP标识
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
                  
                  // 艺术家和专辑
                  Text(
                    '${track.artistNames} • ${track.album.name}',
                    style: SongListStyleConfig.getArtistAlbumStyle(context),
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
                color: SongListStyleConfig.getMoreIconColor(context),
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

  /// 切换搜索框显示状态
  void toggleSearch() {
    _state?._toggleSearch();
  }

  /// 显示搜索框
  void showSearch() {
    _state?._showSearch();
  }

  /// 隐藏搜索框
  void hideSearch() {
    _state?._hideSearch();
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
    this.itemHeight = SongListLayoutConfig.itemHeight,
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
