import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../config/song_list_layout.dart';

/// 混合虚拟滚动列表控制器
class MixedVirtualSongListController {
  _MixedVirtualSongListState? _state;

  void _attach(_MixedVirtualSongListState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// 显示搜索框
  void showSearch() {
    _state?.showSearch();
  }

  /// 定位到指定歌曲
  void scrollToTrack(int trackId) {
    _state?.scrollToTrack(trackId);
  }
}

/// 混合内容项类型
enum MixedItemType {
  track,       // 普通歌曲
  reelHeader,  // 作品集头部信息
  reelSong,    // 作品集中的歌曲
}

/// 混合内容项
class MixedItem {
  final MixedItemType type;
  final Track? track;
  final Map<String, dynamic>? reel;
  final String displayName;
  final String? subtitle;
  final String? reelName;  // 作品集名称，用于reelSong类型
  
  const MixedItem({
    required this.type,
    this.track,
    this.reel,
    required this.displayName,
    this.subtitle,
    this.reelName,
  });
  
  /// 创建普通歌曲项
  factory MixedItem.track(Track track) {
    return MixedItem(
      type: MixedItemType.track,
      track: track,
      displayName: track.name,
      subtitle: track.artistNames,
    );
  }
  
  /// 创建作品集头部项
  factory MixedItem.reelHeader(Map<String, dynamic> reel) {
    final showreelName = reel['showreelName'] as String? ?? '';
    final composerName = reel['composerName'] as String? ?? '';
    
    return MixedItem(
      type: MixedItemType.reelHeader,
      reel: reel,
      displayName: showreelName,
      subtitle: composerName,
    );
  }
  
  /// 创建作品集歌曲项（歌曲名显示为songName）
  factory MixedItem.reelSong(Map<String, dynamic> reel, Track track, String songName) {
    final displayName = songName.isNotEmpty ? songName : track.name;
    return MixedItem(
      type: MixedItemType.reelSong,
      track: track,
      reel: reel,
      displayName: displayName,
      subtitle: track.artistNames,  // 保持原歌手信息
      reelName: songName,
    );
  }
  
  /// 获取对应的Track（用于播放）
  Track? get playableTrack => track;
}

/// 混合虚拟滚动列表组件
class MixedVirtualSongList extends StatefulWidget {
  /// 混合内容列表
  final List<MixedItem> items;
  
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
  
  /// 是否显示内置搜索按钮
  final bool showSearchButton;
  
  /// 搜索提示文本
  final String searchHint;
  
  /// 头部内容构建器
  final Widget Function()? headerBuilder;
  
  /// 头部高度
  final double headerHeight;

  /// 控制器
  final MixedVirtualSongListController? controller;

  const MixedVirtualSongList({
    super.key,
    required this.items,
    this.onTrackTap,
    this.onPlayTap,
    this.onMoreTap,
    this.currentPlayingId,
    this.showIndex = true,
    this.itemHeight = SongListLayoutConfig.itemHeight,
    this.enableSearch = false,
    this.showSearchButton = true,
    this.searchHint = '搜索歌曲',
    this.headerBuilder,
    this.headerHeight = 0,
    this.controller,
  });

  @override
  State<MixedVirtualSongList> createState() => _MixedVirtualSongListState();
}

class _MixedVirtualSongListState extends State<MixedVirtualSongList> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<MixedItem> _filteredItems = [];
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MixedVirtualSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索回调
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          switch (item.type) {
            case MixedItemType.reelHeader:
              // 搜索作品集名称和作曲家
              final displayName = item.displayName.toLowerCase();
              final subtitle = (item.subtitle ?? '').toLowerCase();
              return displayName.contains(query) || subtitle.contains(query);
            case MixedItemType.reelSong:
            case MixedItemType.track:
              // 搜索显示名称和副标题
              final displayName = item.displayName.toLowerCase();
              final subtitle = (item.subtitle ?? '').toLowerCase();
              return displayName.contains(query) || subtitle.contains(query);
          }
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
        _filteredItems = widget.items;
      }
    });
  }

  /// 显示搜索框（公共方法）
  void showSearch() {
    if (!_isSearchVisible) {
      _toggleSearch();
    }
  }

  /// 定位到指定歌曲ID
  void scrollToTrack(int trackId) {
    final index = _filteredItems.indexWhere((item) => item.track?.id == trackId);
    if (index != -1) {
      final targetOffset = widget.headerHeight + (index * widget.itemHeight);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ? '没有找到相关歌曲' : '暂无歌曲',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
              },
              child: const Text('清除搜索'),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建浮动搜索栏
  Widget _buildFloatingSearchBar() {
    return Positioned(
      top: 20,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSearch,
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() {}); // 触发重建以更新suffixIcon
          },
        ),
      ),
    );
  }

  /// 构建混合项
  Widget _buildMixedItem(MixedItem item, int originalIndex, int displayIndex) {
    switch (item.type) {
      case MixedItemType.reelHeader:
        return _buildReelHeader(item);
      case MixedItemType.reelSong:
        return _buildReelSong(item, originalIndex, displayIndex);
      case MixedItemType.track:
        return _buildTrackItem(item, originalIndex, displayIndex);
    }
  }

  /// 构建作品集头部
  Widget _buildReelHeader(MixedItem item) {
    final reel = item.reel!;
    final showreelName = reel['showreelName'] as String? ?? '';
    final composerName = reel['composerName'] as String? ?? '';
    final otherArtists = List<String>.from(reel['otherArtists'] ?? []);

    return Container(
      margin: const EdgeInsets.only(left: 5, right: 16, top: 10, bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), // 5px上下边距
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 作品集名称 - 大字行 24px
          Text(
            showreelName.isNotEmpty ? showreelName : '未命名作品集',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.0, // 确保行高为24px
              fontSize: 15, // 设置字体大小确保24px行高
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (composerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              composerName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.0, // 确保行高为20px
                fontSize: 14, // 设置字体大小为15px
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          if (otherArtists.isNotEmpty) ...[
            ...otherArtists.map((artist) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                artist,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.0, // 确保行高为20px
                  fontSize: 14, // 设置字体大小为14px
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
        ],
      ),
    );
  }

  /// 构建作品集中的歌曲项
  Widget _buildReelSong(MixedItem item, int originalIndex, int displayIndex) {
    final track = item.track;
    if (track == null) return const SizedBox.shrink();
    
    final isCurrentPlaying = track.id == widget.currentPlayingId;
    
    return InkWell(
      onTap: () {
        if (widget.onTrackTap != null) {
          widget.onTrackTap?.call(track, originalIndex);
        } else {
          _playTrackDefault(track);
        }
      },
      child: Container(
        padding: SongListLayoutConfig.itemPadding,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 3,
            ),
          ),
        ),
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
                          '${displayIndex + 1}',
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
                  // 显示reel名称作为歌曲标题
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentPlaying 
                                ? Theme.of(context).primaryColor 
                                : null, // 使用默认文本颜色
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
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // 显示原始歌手信息
                  if (track.artistNames.isNotEmpty)
                    Text(
                      track.artistNames,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // 操作按钮
            _buildActionButtons(track, originalIndex, isCurrentPlaying),
          ],
        ),
      ),
    );
  }

  /// 构建普通歌曲项
  Widget _buildTrackItem(MixedItem item, int originalIndex, int displayIndex) {
    final track = item.track;
    if (track == null) return const SizedBox.shrink();
    
    final isCurrentPlaying = track.id == widget.currentPlayingId;
    
    return InkWell(
      onTap: () {
        if (widget.onTrackTap != null) {
          widget.onTrackTap?.call(track, originalIndex);
        } else {
          _playTrackDefault(track);
        }
      },
      child: Container(
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
                          '${displayIndex + 1}',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentPlaying ? Theme.of(context).primaryColor : null,
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
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 2),
                  
                  // 歌手信息
                  if (track.artistNames.isNotEmpty)
                    Text(
                      track.artistNames,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // 操作按钮
            _buildActionButtons(track, originalIndex, isCurrentPlaying),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(Track track, int originalIndex, bool isCurrentPlaying) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 更多操作
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey[600],
          ),
          onPressed: () {
            widget.onMoreTap?.call(track, originalIndex);
          },
        ),
      ],
    );
  }

  /// 默认播放方法
  void _playTrackDefault(Track track) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    // 获取所有可播放的Track
    final allTracks = widget.items
        .where((item) => item.track != null)
        .map((item) => item.track!)
        .toList();
    final trackIndex = allTracks.indexOf(track);
    if (trackIndex >= 0) {
      playerService.setPlaylist(allTracks, trackIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 处理空状态
    if (_filteredItems.isEmpty) {
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
              
              // 搜索栏（如果启用）
              if (widget.enableSearch && !_isSearchVisible)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_filteredItems.length} 项内容',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        if (widget.showSearchButton)
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _toggleSearch,
                            tooltip: '搜索',
                          ),
                      ],
                    ),
                  ),
                ),
              
              // 混合内容列表
              SliverList.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final originalIndex = widget.items.indexOf(item);
                  
                  // 根据项目类型确定高度
                  double itemHeight = widget.itemHeight;
                  if (item.type == MixedItemType.reelHeader) {
                    // 作品集头部需要更多高度
                    itemHeight = _calculateReelHeaderHeight(item);
                  }
                  
                  return SizedBox(
                    height: itemHeight,
                    child: _buildMixedItem(item, originalIndex, index),
                  );
                },
              ),
              
              // 底部空白
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          
          // 浮动搜索栏
          if (widget.enableSearch && _isSearchVisible) _buildFloatingSearchBar(),
        ],
      );
    }

    // 没有头部内容，使用ListView
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: _filteredItems.length,
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            final originalIndex = widget.items.indexOf(item);
            
            // 根据项目类型确定高度
            double itemHeight = widget.itemHeight;
            if (item.type == MixedItemType.reelHeader) {
              itemHeight = _calculateReelHeaderHeight(item);
            }
            
            return SizedBox(
              height: itemHeight,
              child: _buildMixedItem(item, originalIndex, index),
            );
          },
        ),
        
        // 浮动搜索栏
        if (widget.enableSearch && _isSearchVisible) _buildFloatingSearchBar(),
      ],
    );
  }

  /// 计算作品集头部高度
  double _calculateReelHeaderHeight(MixedItem item) {
    if (item.reel == null) return 54.0; // 5 + 24 + 8 + 20 + 5 (最小高度)
    
    final reel = item.reel!;
    final composerName = reel['composerName'] as String? ?? '';
    final otherArtists = List<String>.from(reel['otherArtists'] ?? []);
    
    double height = 10.0; // 上下边距 5px + 5px
    height += 24.0; // 大字行（作品集名称）24px
    
    if (composerName.isNotEmpty) {
      height += 8.0; // 间距 (对应 SizedBox(height: 8))
      height += 20.0; // 小字行（作曲家）20px
    }
    
    if (otherArtists.isNotEmpty) {
      height += otherArtists.length * 20.0; // 每个艺术家信息小字行 20px
      height += otherArtists.length * 8.0; // 每个艺术家上方的 8px padding
    }
    
    return height;
  }
}
