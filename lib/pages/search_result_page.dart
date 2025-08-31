import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_manager.dart';
import '../services/player_service.dart';
import '../utils/app_logger.dart';
import '../models/playlist.dart';
import '../config/song_list_layout.dart';
import '../config/search_bar_config.dart';
import '../pages/player_page.dart';
import '../widgets/playlist_sheet.dart';
import '../widgets/virtual_song_list.dart';

/// 搜索结果页面
class SearchResultPage extends StatefulWidget {
  final String query;
  final int initialType;

  const SearchResultPage({
    super.key,
    required this.query,
    this.initialType = 1, // 默认搜索歌曲
  });

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // 搜索类型和对应的名称
  final Map<int, String> _searchTypes = {
    1: '歌曲',
    100: '歌手',
    10: '专辑',
    1000: '歌单',
    1002: '用户',
    1006: '歌词',
  };

  // 搜索结果数据
  Map<int, List<dynamic>> _searchResults = {};
  Map<int, int> _searchCounts = {};
  Map<int, bool> _isLoading = {};

  // 分页相关
  Map<int, int> _currentPages = {};
  final int _pageSize = 30;

  // 管理每个歌曲的歌词展开状态
  final Set<int> _expandedLyrics = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _searchTypes.length,
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );

    // 初始化状态
    for (int type in _searchTypes.keys) {
      _searchResults[type] = [];
      _searchCounts[type] = 0;
      _isLoading[type] = false;
      _currentPages[type] = 0;
    }

    // 监听tab切换
    _tabController.addListener(_onTabChanged);

    // 加载初始数据
    _loadSearchResults(widget.initialType);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 获取初始Tab索引
  int _getInitialTabIndex() {
    final typesList = _searchTypes.keys.toList();
    return typesList.indexOf(widget.initialType);
  }

  /// Tab切换监听
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final typesList = _searchTypes.keys.toList();
    final currentType = typesList[_tabController.index];

    // 如果该类型还没有数据，则加载
    if (_searchResults[currentType]?.isEmpty == true &&
        !_isLoading[currentType]!) {
      _loadSearchResults(currentType);
    }
  }

  /// 加载搜索结果
  Future<void> _loadSearchResults(int type, {bool loadMore = false}) async {
    if (_isLoading[type] == true) return;

    setState(() {
      _isLoading[type] = true;
    });

    try {
      final api = ApiManager();
      final offset = loadMore ? (_currentPages[type]! + 1) * _pageSize : 0;

      final result = await api.api.cloudsearch(
        keywords: widget.query,
        type: type.toString(),
        limit: 100,
        offset: offset,
      );

      if (result['body']['code'] == 200) {
        final data = result['body']['result'];

        List<dynamic> newItems = [];
        int totalCount = 0;

        // 根据类型解析数据
        switch (type) {
          case 1: // 歌曲
            newItems = data['songs'] ?? [];
            totalCount = data['songCount'] ?? 0;
            break;
          case 100: // 歌手
            newItems = data['artists'] ?? [];
            totalCount = data['artistCount'] ?? 0;
            break;
          case 10: // 专辑
            newItems = data['albums'] ?? [];
            totalCount = data['albumCount'] ?? 0;
            break;
          case 1000: // 歌单
            newItems = data['playlists'] ?? [];
            totalCount = data['playlistCount'] ?? 0;
            break;
          case 1002: // 用户
            newItems = data['userprofiles'] ?? [];
            totalCount = data['userprofileCount'] ?? 0;
            break;
          case 1006: // 歌词
            newItems = data['songs'] ?? [];
            totalCount = data['songCount'] ?? 0;
            break;
        }

        setState(() {
          if (loadMore) {
            _searchResults[type]!.addAll(newItems);
            _currentPages[type] = _currentPages[type]! + 1;
          } else {
            _searchResults[type] = newItems;
            _currentPages[type] = 0;
          }
          _searchCounts[type] = totalCount;
          _isLoading[type] = false;
        });

        AppLogger.info(
          '搜索结果加载完成: 类型=$type, 数量=${newItems.length}, 总数=$totalCount',
        );
      } else {
        throw Exception('搜索失败: ${result['body']['code']}');
      }
    } catch (e) {
      AppLogger.error('搜索失败', e);
      setState(() {
        _isLoading[type] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
      }
    }
  }

  /// 构建顶部搜索框
  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 返回到搜索页面，保持当前搜索关键词
        Navigator.of(context).pop(widget.query);
      },
      child: Container(
        height: SearchBarConfig.height,
        decoration: SearchBarConfig.getContainerDecoration(context),
        child: Row(
          children: [
            SizedBox(width: SearchBarConfig.iconTextSpacing),
            SearchBarConfig.getSearchIcon(context),
            SizedBox(width: SearchBarConfig.iconTextSpacing),
            Expanded(
              child: Text(
                widget.query,
                style: SearchBarConfig.getInputTextStyle(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: SearchBarConfig.iconTextSpacing),
          ],
        ),
      ),
    );
  }

  /// 构建Tab标签
  List<Tab> _buildTabs() {
    return _searchTypes.entries.map((entry) {
      return Tab(text: entry.value);
    }).toList();
  }

  /// 构建歌曲列表
  Widget _buildSongList(List<dynamic> songs, {bool isLyricsSearch = false}) {
    if (songs.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }

    // 对于歌词搜索，由于需要显示歌词内容，使用ListView并添加触底加载
    if (isLyricsSearch) {
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // 检查是否滚动到底部
          if (!_isLoading[1006]! &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            final currentCount = _searchResults[1006]?.length ?? 0;
            final totalCount = _searchCounts[1006] ?? 0;
            if (currentCount < totalCount) {
              _loadSearchResults(1006, loadMore: true);
            }
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 100), // 为浮动播放控件预留空间
          itemCount: songs.length + (_shouldShowLoadingIndicator(1006) ? 1 : 0),
          itemBuilder: (context, index) {
            // 如果是最后一项且正在加载，显示加载指示器
            if (index == songs.length) {
              return _buildLoadingIndicator(1006);
            }

            final song = songs[index];
            try {
              final track = Track.fromJson(song);

              // 提取歌词信息
              List<String>? lyrics;
              if (song['lyrics'] != null) {
                lyrics = (song['lyrics'] as List).cast<String>();
              }

              return _buildSongItem(track, index, lyrics: lyrics);
            } catch (e) {
              AppLogger.error('解析歌曲数据失败', e);
              return ListTile(
                title: Text(song['name'] ?? '未知歌曲'),
                subtitle: Text('数据解析失败'),
              );
            }
          },
        ),
      );
    }

    // 将动态类型转换为Track列表（非歌词搜索）
    List<Track> tracks = [];
    for (int i = 0; i < songs.length; i++) {
      try {
        tracks.add(Track.fromJson(songs[i]));
      } catch (e) {
        AppLogger.error('解析歌曲数据失败', e);
        // 跳过解析失败的歌曲
        continue;
      }
    }

    if (tracks.isEmpty) {
      return const Center(child: Text('暂无有效歌曲数据'));
    }

    // 使用虚拟滚动组件，并添加触底加载支持
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // 检查是否滚动到底部
        if (!_isLoading[1]! &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 100) {
          // 提前100px触发
          final currentCount = _searchResults[1]?.length ?? 0;
          final totalCount = _searchCounts[1] ?? 0;
          if (currentCount < totalCount) {
            _loadSearchResults(1, loadMore: true);
          }
        }
        return false;
      },
      child: Column(
        children: [
          Expanded(
            child: VirtualSongList(
              tracks: tracks,
              showIndex: true,
              enableSearch: false, // 搜索结果页面不需要内置搜索
              itemHeight: SongListLayoutConfig.itemHeight,
              onTrackTap: (track, index) {
                _playTrack(track, index, tracks);
              },
              onPlayTap: (track, index) {
                _playTrack(track, index, tracks);
              },
              onMoreTap: (track, index) {
                // TODO: 显示更多操作菜单
                AppLogger.info('点击更多操作: ${track.name}');
              },
            ),
          ),
          // 显示加载状态
          if (_shouldShowLoadingIndicator(1)) _buildLoadingIndicator(1),
        ],
      ),
    );
  }

  /// 播放歌曲的统一方法
  void _playTrack(Track track, int index, List<Track> allTracks) {
    AppLogger.info('点击歌曲: ${track.name}');
    final playerService = Provider.of<PlayerService>(context, listen: false);

    // 设置播放列表并播放指定歌曲
    playerService.playPlaylist(allTracks, startIndex: index);
    AppLogger.info('开始播放: ${track.name}');
  }

  /// 构建歌曲项
  Widget _buildSongItem(Track track, int index, {List<String>? lyrics}) {
    return Padding(
      padding: SongListLayoutConfig.itemPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主要歌曲信息行 - 只有这部分可以点击播放
          InkWell(
            onTap: () {
              AppLogger.info('点击歌曲: ${track.name}');
              // 实现播放逻辑：将当前搜索结果设为播放列表并播放选中歌曲
              final playerService = Provider.of<PlayerService>(
                context,
                listen: false,
              );
              final searchType = _searchTypes.keys
                  .toList()[_tabController.index];
              final songs = _searchResults[searchType] ?? [];

              // 将搜索结果转换为Track列表
              List<Track> tracks = [];
              for (var song in songs) {
                try {
                  tracks.add(Track.fromJson(song));
                } catch (e) {
                  AppLogger.error('转换歌曲数据失败', e);
                }
              }

              if (tracks.isNotEmpty) {
                // 设置播放列表并播放指定歌曲
                playerService.playPlaylist(tracks, startIndex: index);
                AppLogger.info('开始播放: ${track.name}');
              }
            },
            child: Row(
              children: [
                // 序号
                SizedBox(
                  width: SongListLayoutConfig.indexWidth,
                  child: Text(
                    '${index + 1}',
                    style: SongListStyleConfig.getIndexStyle(context),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: SongListLayoutConfig.spacingMedium),

                // 歌曲封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    SongListLayoutConfig.albumCoverRadius,
                  ),
                  child: Image.network(
                    "${track.album.picUrl}${SongListLayoutConfig.albumCoverParam}",
                    width: SongListLayoutConfig.albumCoverSize,
                    height: SongListLayoutConfig.albumCoverSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: SongListLayoutConfig.albumCoverSize,
                        height: SongListLayoutConfig.albumCoverSize,
                        color: SongListStyleConfig.getErrorBackgroundColor(
                          context,
                        ),
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
                    children: [
                      // 歌曲名
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.name,
                              style: SongListStyleConfig.getSongNameStyle(
                                context,
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
                                borderRadius: BorderRadius.circular(
                                  SongListLayoutConfig.vipRadius,
                                ),
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
                  onPressed: () {
                    // TODO: 显示更多操作菜单
                    AppLogger.info('点击更多操作: ${track.name}');
                  },
                ),
              ],
            ),
          ),

          // 歌词展示（仅在歌词搜索时显示，另开一行，不可点击播放）
          if (lyrics != null && lyrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(
                left:
                    SongListLayoutConfig.indexWidth +
                    SongListLayoutConfig.spacingMedium,
              ),
              child: _buildLyricsWidget(lyrics, track.id),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建歌词组件（带展开/收起功能）
  Widget _buildLyricsWidget(List<String> lyrics, int trackId) {
    return StatefulBuilder(
      builder: (context, setState) {
        // 为每个歌曲维护独立的展开状态
        final isExpanded = _expandedLyrics.contains(trackId);

        // 处理原始歌词，保持原始顺序
        final processedLyrics = _processLyrics(lyrics);

        // 根据展开状态选择显示内容：
        // - 展开状态：显示完整的原始歌词（按原始顺序）
        // - 收起状态：显示智能选择的预览片段（包含加粗行的上下文）
        final displayLyrics = isExpanded
            ? processedLyrics // 完整原始歌词，加粗行在正确位置
            : _getCollapsedLyrics(processedLyrics); // 预览片段，加粗行优先显示

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 歌词标题和展开按钮
              Row(
                children: [
                  Icon(
                    Icons.lyrics,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '歌词片段',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (processedLyrics.length > 3) // 只有歌词较多时才显示展开按钮
                    InkWell(
                      onTap: () {
                        // 阻止事件冒泡到父级InkWell
                        setState(() {
                          if (isExpanded) {
                            _expandedLyrics.remove(trackId);
                          } else {
                            _expandedLyrics.add(trackId);
                          }
                        });
                      },
                      // 使用自定义形状避免点击区域过大
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isExpanded ? '收起' : '展开',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // 歌词内容
              ...displayLyrics
                  .map(
                    (lyricData) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _buildLyricLine(lyricData),
                    ),
                  )
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  /// 构建单行歌词（支持加粗显示）
  Widget _buildLyricLine(Map<String, dynamic> lyricData) {
    final text = lyricData['text'] as String;
    final highlights = lyricData['highlights'] as List<Map<String, int>>;
    final isEllipsis = lyricData['isEllipsis'] as bool? ?? false;

    // 如果是省略指示符，使用特殊样式
    if (isEllipsis) {
      return Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (highlights.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.3,
        ),
        softWrap: true,
      );
    }

    // 构建富文本，包含加粗部分
    List<TextSpan> spans = [];
    int lastEnd = 0;

    for (var highlight in highlights) {
      final start = highlight['start']!;
      final end = highlight['end']!;

      // 添加普通文本
      if (start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, start),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        );
      }

      // 添加加粗文本
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
      );

      lastEnd = end;
    }

    // 添加剩余的普通文本
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.3,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans), softWrap: true);
  }

  /// 处理歌词，解析HTML标签并提取高亮信息
  List<Map<String, dynamic>> _processLyrics(List<String> lyrics) {
    List<Map<String, dynamic>> processed = [];

    for (String lyric in lyrics) {
      if (lyric.trim().isEmpty) continue;

      String cleanText = '';
      List<Map<String, int>> highlights = [];
      int currentPos = 0;

      // 使用正则表达式匹配<b>标签
      final RegExp boldRegex = RegExp(r'<b>(.*?)</b>');
      final matches = boldRegex.allMatches(lyric);

      int lastEnd = 0;
      for (var match in matches) {
        // 添加标签前的文本
        String beforeText = lyric.substring(lastEnd, match.start);
        cleanText += beforeText;
        currentPos += beforeText.length;

        // 添加标签内的文本，并记录高亮位置
        String boldText = match.group(1) ?? '';
        int startPos = currentPos;
        cleanText += boldText;
        currentPos += boldText.length;

        if (boldText.isNotEmpty) {
          highlights.add({'start': startPos, 'end': currentPos});
        }

        lastEnd = match.end;
      }

      // 添加剩余文本
      cleanText += lyric.substring(lastEnd);

      // 移除其他HTML标签
      cleanText = cleanText.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (cleanText.isNotEmpty) {
        processed.add({
          'text': cleanText,
          'highlights': highlights,
          'hasHighlight': highlights.isNotEmpty,
        });
      }
    }

    return processed;
  }

  /// 获取收起状态下的歌词（显示加粗部分附近的几行）
  List<Map<String, dynamic>> _getCollapsedLyrics(
    List<Map<String, dynamic>> processedLyrics,
  ) {
    if (processedLyrics.length <= 3) {
      return processedLyrics;
    }

    // 找到包含高亮的行
    List<int> highlightIndexes = [];
    for (int i = 0; i < processedLyrics.length; i++) {
      if (processedLyrics[i]['hasHighlight'] == true) {
        highlightIndexes.add(i);
      }
    }

    if (highlightIndexes.isEmpty) {
      // 如果没有高亮，显示前3行
      return processedLyrics.take(3).toList();
    }

    // 选择最佳的高亮行来作为预览中心
    // 优先选择位置较靠前但不是第一行的高亮行，这样能提供更好的上下文
    int centerIndex = highlightIndexes.first;
    for (int index in highlightIndexes) {
      if (index > 0 && index < processedLyrics.length - 1) {
        centerIndex = index;
        break;
      }
    }

    // 计算要显示的行范围，确保总共显示3行
    int startIndex = (centerIndex - 1).clamp(0, processedLyrics.length);
    int endIndex = (startIndex + 3).clamp(0, processedLyrics.length);

    // 如果end超出范围，调整start
    if (endIndex - startIndex < 3 && startIndex > 0) {
      startIndex = (endIndex - 3).clamp(0, processedLyrics.length);
    }

    // 为收起状态的歌词添加位置信息，用于在展开时显示正确提示
    List<Map<String, dynamic>> collapsedLyrics = processedLyrics.sublist(
      startIndex,
      endIndex,
    );

    // 如果收起的内容不是从开头开始，添加省略指示
    if (startIndex > 0) {
      collapsedLyrics.insert(0, {
        'text': '...',
        'highlights': <Map<String, int>>[],
        'hasHighlight': false,
        'isEllipsis': true,
      });
    }

    // 如果收起的内容不是到结尾，添加省略指示
    if (endIndex < processedLyrics.length) {
      collapsedLyrics.add({
        'text': '...',
        'highlights': <Map<String, int>>[],
        'hasHighlight': false,
        'isEllipsis': true,
      });
    }

    return collapsedLyrics;
  }

  /// 判断是否应该显示加载指示器
  bool _shouldShowLoadingIndicator(int type) {
    final isLoading = _isLoading[type] == true;
    final currentCount = _searchResults[type]?.length ?? 0;
    final totalCount = _searchCounts[type] ?? 0;
    // 只有在正在加载时才显示指示器
    return isLoading && currentCount < totalCount;
  }

  /// 构建加载指示器
  Widget _buildLoadingIndicator(int type) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// 构建歌手列表
  Widget _buildArtistList(List<dynamic> artists) {
    if (artists.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // 检查是否滚动到底部
        if (!_isLoading[100]! &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          final currentCount = _searchResults[100]?.length ?? 0;
          final totalCount = _searchCounts[100] ?? 0;
          if (currentCount < totalCount) {
            _loadSearchResults(100, loadMore: true);
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // 为浮动播放控件预留空间
        itemCount: artists.length + (_shouldShowLoadingIndicator(100) ? 1 : 0),
        itemBuilder: (context, index) {
          // 如果是最后一项且正在加载，显示加载指示器
          if (index == artists.length) {
            return _buildLoadingIndicator(100);
          }

          final artist = artists[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: artist['picUrl'] != null
                  ? NetworkImage('${artist['picUrl']}?param=50y50')
                  : null,
              child: artist['picUrl'] == null ? const Icon(Icons.person) : null,
            ),
            title: Text(artist['name'] ?? '未知歌手'),
            subtitle: Text(
              '专辑 ${artist['albumSize'] ?? 0} · 歌曲 ${artist['musicSize'] ?? 0}',
            ),
            onTap: () {
              AppLogger.info('点击歌手: ${artist['name']}');
              // TODO: 跳转到歌手页面
            },
          );
        },
      ),
    );
  }

  /// 构建专辑列表
  Widget _buildAlbumList(List<dynamic> albums) {
    if (albums.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // 检查是否滚动到底部
        if (!_isLoading[10]! &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          final currentCount = _searchResults[10]?.length ?? 0;
          final totalCount = _searchCounts[10] ?? 0;
          if (currentCount < totalCount) {
            _loadSearchResults(10, loadMore: true);
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // 为浮动播放控件预留空间
        itemCount: albums.length + (_shouldShowLoadingIndicator(10) ? 1 : 0),
        itemBuilder: (context, index) {
          // 如果是最后一项且正在加载，显示加载指示器
          if (index == albums.length) {
            return _buildLoadingIndicator(10);
          }

          final album = albums[index];
          return ListTile(
            leading: album['picUrl'] != null
                ? Image.network(
                    '${album['picUrl']}?param=50y50',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: const Icon(Icons.album),
                  ),
            title: Text(album['name'] ?? '未知专辑'),
            subtitle: Text(
              '${album['artist']?['name'] ?? '未知歌手'} · ${album['size'] ?? 0}首',
            ),
            onTap: () {
              AppLogger.info('点击专辑: ${album['name']}');
              // TODO: 跳转到专辑页面
              Navigator.pushNamed(
                context,
                '/album_detail',
                arguments: {
                  'albumId': album['id']?.toString() ?? '',
                  'albumName': album['name'],
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 构建歌单列表
  Widget _buildPlaylistList(List<dynamic> playlists) {
    if (playlists.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // 检查是否滚动到底部
        if (!_isLoading[1000]! &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          final currentCount = _searchResults[1000]?.length ?? 0;
          final totalCount = _searchCounts[1000] ?? 0;
          if (currentCount < totalCount) {
            _loadSearchResults(1000, loadMore: true);
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // 为浮动播放控件预留空间
        itemCount:
            playlists.length + (_shouldShowLoadingIndicator(1000) ? 1 : 0),
        itemBuilder: (context, index) {
          // 如果是最后一项且正在加载，显示加载指示器
          if (index == playlists.length) {
            return _buildLoadingIndicator(1000);
          }

          final playlist = playlists[index];
          return ListTile(
            leading: playlist['coverImgUrl'] != null
                ? Image.network(
                    '${playlist['coverImgUrl']}?param=50y50',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: const Icon(Icons.queue_music),
                  ),
            title: Text(playlist['name'] ?? '未知歌单'),
            subtitle: Text(
              '${playlist['creator']?['nickname'] ?? '未知用户'} · ${playlist['trackCount'] ?? 0}首',
            ),
            onTap: () {
              AppLogger.info('点击歌单: ${playlist['name']}');
              // TODO: 跳转到歌单页面
              Navigator.pushNamed(
                context,
                '/playlist_detail',
                arguments: {
                  'playlistId': playlist['id']?.toString() ?? '',
                  'playlistName': playlist['name'],
                },
              );
            },
          );
        },
      ),
    );
  }

  /// 构建用户列表
  Widget _buildUserList(List<dynamic> users) {
    if (users.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // 检查是否滚动到底部
        if (!_isLoading[1002]! &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          final currentCount = _searchResults[1002]?.length ?? 0;
          final totalCount = _searchCounts[1002] ?? 0;
          if (currentCount < totalCount) {
            _loadSearchResults(1002, loadMore: true);
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100), // 为浮动播放控件预留空间
        itemCount: users.length + (_shouldShowLoadingIndicator(1002) ? 1 : 0),
        itemBuilder: (context, index) {
          // 如果是最后一项且正在加载，显示加载指示器
          if (index == users.length) {
            return _buildLoadingIndicator(1002);
          }

          final user = users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user['avatarUrl'] != null
                  ? NetworkImage('${user['avatarUrl']}?param=50y50')
                  : null,
              child: user['avatarUrl'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(user['nickname'] ?? '未知用户'),
            subtitle: Text(user['signature'] ?? ''),
            onTap: () {
              AppLogger.info('点击用户: ${user['nickname']}');
              // TODO: 跳转到用户页面
            },
          );
        },
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(int type) {
    if (_isLoading[type] == true && (_searchResults[type]?.isEmpty == true)) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = _searchResults[type] ?? [];

    switch (type) {
      case 1: // 歌曲
        return _buildSongList(results);
      case 1006: // 歌词 (也显示歌曲，但包含歌词信息)
        return _buildSongList(results, isLyricsSearch: true);
      case 100: // 歌手
        return _buildArtistList(results);
      case 10: // 专辑
        return _buildAlbumList(results);
      case 1000: // 歌单
        return _buildPlaylistList(results);
      case 1002: // 用户
        return _buildUserList(results);
      default:
        return const Center(child: Text('不支持的搜索类型'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: _buildSearchBar(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: _buildTabs(),
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      body: Stack(
        children: [
          // 主要内容区域
          TabBarView(
            controller: _tabController,
            children: _searchTypes.keys.map((type) {
              return _buildContent(type);
            }).toList(),
          ),
          // 浮动播放控件
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: Consumer<PlayerService>(
              builder: (context, playerService, child) {
                final currentTrack = playerService.currentTrack;
                // 只有在有当前播放歌曲时才显示浮动控件
                if (currentTrack == null) {
                  return const SizedBox.shrink();
                }
                return _buildFloatingPlayerBar(
                  context,
                  playerService,
                  currentTrack,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建浮动播放控件
  Widget _buildFloatingPlayerBar(
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.music_note,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.music_note,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (currentTrack.artists.isNotEmpty)
                            Text(
                              '${currentTrack.artists.map((artist) => artist.name).join(', ')} · ${currentTrack.album.name}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                          playerService.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
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
                      onTap: () =>
                          _showPlaylist(context, playerService, currentTrack),
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
  void _showPlaylist(
    BuildContext context,
    PlayerService playerService,
    Track? currentTrack,
  ) {
    PlaylistSheet.show(context, currentTrack);
  }
}
