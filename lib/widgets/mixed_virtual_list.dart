import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../config/song_list_layout.dart';

/// 混合虚拟滚动列表项类型
enum MixedListItemType {
  track,
  reelGroup,
}

/// 混合列表项基类
abstract class MixedListItem {
  MixedListItemType get type;
}

/// 普通歌曲项
class TrackListItem extends MixedListItem {
  final Track track;
  final int originalIndex;

  TrackListItem({
    required this.track,
    required this.originalIndex,
  });

  @override
  MixedListItemType get type => MixedListItemType.track;
}

/// Reel组项（作为歌曲项显示）
class ReelGroupItem extends MixedListItem {
  final String reelName;
  final List<ReelSongItem> songs;
  final String? composerName;
  final List<String> otherArtists;

  ReelGroupItem({
    required this.reelName,
    required this.songs,
    this.composerName,
    this.otherArtists = const [],
  });

  @override
  MixedListItemType get type => MixedListItemType.reelGroup;
}

/// Reel中的歌曲项
class ReelSongItem {
  final String songId;
  final String reelSongName;
  final Track? track; // 对应的完整Track对象

  ReelSongItem({
    required this.songId,
    required this.reelSongName,
    this.track,
  });
}

/// 混合内容虚拟滚动列表组件
class MixedVirtualList extends StatefulWidget {
  /// 所有歌曲列表（用于播放）
  final List<Track> allTracks;
  
  /// 混合列表项
  final List<MixedListItem> items;
  
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

  const MixedVirtualList({
    super.key,
    required this.allTracks,
    required this.items,
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
  State<MixedVirtualList> createState() => _MixedVirtualListState();
}

class _MixedVirtualListState extends State<MixedVirtualList> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<MixedListItem> _filteredItems = [];
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(MixedVirtualList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      setState(() {
        _filteredItems = widget.items;
        _filterItems();
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
    _filterItems();
  }

  /// 过滤列表项
  void _filterItems() {
    final query = _searchController.text.toLowerCase().trim();
    
    if (query.isEmpty) {
      setState(() {
        _filteredItems = widget.items;
      });
      return;
    }

    setState(() {
      _filteredItems = widget.items.where((item) {
        switch (item.type) {
          case MixedListItemType.track:
            final trackItem = item as TrackListItem;
            final track = trackItem.track;
            return track.name.toLowerCase().contains(query) ||
                   track.artists.any((artist) => artist.name.toLowerCase().contains(query)) ||
                   track.album.name.toLowerCase().contains(query);
          
          case MixedListItemType.reelGroup:
            final reelItem = item as ReelGroupItem;
            return reelItem.reelName.toLowerCase().contains(query) ||
                   reelItem.songs.any((song) => 
                       song.reelSongName.toLowerCase().contains(query) ||
                       (song.track?.name.toLowerCase().contains(query) ?? false));
        }
      }).toList();
    });
  }

  /// 切换搜索栏显示状态
  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _filteredItems = widget.items;
      }
    });
  }

  /// 计算展开后的总项目数（包括reel中的子项）
  int _calculateExpandedItemCount() {
    int count = 0;
    for (final item in _filteredItems) {
      switch (item.type) {
        case MixedListItemType.track:
          count++;
          break;
        case MixedListItemType.reelGroup:
          final reelItem = item as ReelGroupItem;
          count += reelItem.songs.length;
          break;
      }
    }
    return count;
  }

  /// 获取展开后的项目（用于ListView.builder）
  Widget _getExpandedItem(int index) {
    int currentIndex = 0;
    
    for (final item in _filteredItems) {
      switch (item.type) {
        case MixedListItemType.track:
          if (currentIndex == index) {
            final trackItem = item as TrackListItem;
            return _buildTrackItem(trackItem.track, trackItem.originalIndex, index);
          }
          currentIndex++;
          break;
          
        case MixedListItemType.reelGroup:
          final reelItem = item as ReelGroupItem;
          for (int i = 0; i < reelItem.songs.length; i++) {
            if (currentIndex == index) {
              return _buildReelSongItem(reelItem, reelItem.songs[i], index);
            }
            currentIndex++;
          }
          break;
      }
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final expandedItemCount = _calculateExpandedItemCount();
    
    return Column(
      children: [
        // 搜索栏
        if (widget.enableSearch) _buildSearchBar(),
        
        // 列表内容
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: (widget.headerBuilder != null ? 1 : 0) + expandedItemCount,
            itemBuilder: (context, index) {
              // 头部内容
              if (widget.headerBuilder != null && index == 0) {
                return widget.headerBuilder!();
              }
              
              // 调整索引（如果有头部）
              final itemIndex = widget.headerBuilder != null ? index - 1 : index;
              return _getExpandedItem(itemIndex);
            },
          ),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isSearchVisible ? 56 : 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchController,
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
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSearch,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          onChanged: (value) {
            setState(() {}); // 触发重建以更新suffixIcon
          },
        ),
      ),
    );
  }

  /// 构建普通歌曲项
  Widget _buildTrackItem(Track track, int originalIndex, int displayIndex) {
    final isCurrentPlaying = track.id == widget.currentPlayingId;
    
    return InkWell(
      onTap: () {
        if (widget.onTrackTap != null) {
          widget.onTrackTap?.call(track, originalIndex);
        } else {
          final playerService = Provider.of<PlayerService>(context, listen: false);
          playerService.setPlaylist(widget.allTracks, originalIndex);
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
                          color: Theme.of(context).primaryColor,
                          size: SongListLayoutConfig.playingIconSize,
                        )
                      : Text(
                          '${originalIndex + 1}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
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
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.music_note,
                      color: Colors.grey[600],
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
                  Text(
                    track.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrentPlaying ? FontWeight.w600 : FontWeight.normal,
                      color: isCurrentPlaying ? Theme.of(context).primaryColor : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 艺术家和专辑
                  Text(
                    '${track.artists.map((a) => a.name).join(', ')} • ${track.album.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // 更多操作按钮
            IconButton(
              icon: const Icon(Icons.more_vert),
              iconSize: 20,
              color: Colors.grey[600],
              onPressed: () {
                widget.onMoreTap?.call(track, originalIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建Reel歌曲项（显示为普通歌曲项，但标题是reel名称）
  Widget _buildReelSongItem(ReelGroupItem reelGroup, ReelSongItem reelSong, int displayIndex) {
    final track = reelSong.track;
    final isCurrentPlaying = track?.id == widget.currentPlayingId;
    
    // 找到这首歌在完整列表中的索引
    final originalIndex = track != null 
        ? widget.allTracks.indexWhere((t) => t.id == track.id) 
        : -1;
    
    return InkWell(
      onTap: track != null && originalIndex >= 0 ? () {
        if (widget.onTrackTap != null) {
          widget.onTrackTap?.call(track, originalIndex);
        } else {
          final playerService = Provider.of<PlayerService>(context, listen: false);
          playerService.setPlaylist(widget.allTracks, originalIndex);
        }
      } : null,
      child: Padding(
        padding: SongListLayoutConfig.itemPadding,
        child: Row(
          children: [
            // 序号或播放状态
            SizedBox(
              width: SongListLayoutConfig.indexWidth,
              child: widget.showIndex && originalIndex >= 0
                  ? isCurrentPlaying
                      ? Icon(
                          Icons.volume_up,
                          color: Theme.of(context).primaryColor,
                          size: SongListLayoutConfig.playingIconSize,
                        )
                      : Text(
                          '${originalIndex + 1}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        )
                  : const SizedBox(),
            ),
            
            const SizedBox(width: SongListLayoutConfig.spacingMedium),
            
            // 歌曲封面（如果有对应的track）
            ClipRRect(
              borderRadius: BorderRadius.circular(SongListLayoutConfig.albumCoverRadius),
              child: track != null
                  ? Image.network(
                      "${track.album.picUrl}${SongListLayoutConfig.albumCoverParam}",
                      width: SongListLayoutConfig.albumCoverSize,
                      height: SongListLayoutConfig.albumCoverSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultCover();
                      },
                    )
                  : _buildDefaultCover(),
            ),
            
            const SizedBox(width: SongListLayoutConfig.spacingMedium),
            
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 使用reel名称作为标题，子项名称作为副标题
                  Text(
                    reelGroup.reelName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isCurrentPlaying ? FontWeight.w600 : FontWeight.w500,
                      color: isCurrentPlaying ? Theme.of(context).primaryColor : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 显示reel子项名称和作曲家信息
                  Text(
                    reelSong.reelSongName + 
                    (reelGroup.composerName?.isNotEmpty == true ? ' • ${reelGroup.composerName}' : ''),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // 更多操作按钮
            IconButton(
              icon: const Icon(Icons.more_vert),
              iconSize: 20,
              color: track != null ? Colors.grey[600] : Colors.grey[400],
              onPressed: track != null && originalIndex >= 0 ? () {
                widget.onMoreTap?.call(track, originalIndex);
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建默认封面
  Widget _buildDefaultCover() {
    return Container(
      width: SongListLayoutConfig.albumCoverSize,
      height: SongListLayoutConfig.albumCoverSize,
      color: Colors.grey[300],
      child: Icon(
        Icons.music_note,
        color: Colors.grey[600],
        size: SongListLayoutConfig.errorIconSize,
      ),
    );
  }
}
