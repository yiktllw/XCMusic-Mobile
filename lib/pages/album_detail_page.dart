import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/api_manager.dart';
import '../services/player_service.dart';
import '../widgets/mixed_virtual_song_list.dart';
import '../widgets/song_detail_panel.dart';
import '../utils/app_logger.dart';
import '../utils/top_banner.dart';

/// 专辑详情页面
class AlbumDetailPage extends StatefulWidget {
  final String albumId;
  final String? albumName;

  const AlbumDetailPage({
    super.key,
    required this.albumId,
    this.albumName,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  Map<String, dynamic>? _albumDetail;
  List<Track> _tracks = [];
  List<Map<String, dynamic>> _showreels = [];
  List<MixedItem> _mixedItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAlbumDetail();
  }

  /// 加载专辑详情
  Future<void> _loadAlbumDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final response = await ApiManager().api.apiAlbumV3Detail(
        id: widget.albumId,
      );

      if (response['status'] == 200) {
        final body = response['body'] as Map<String, dynamic>;
        
        setState(() {
          _albumDetail = body['album'];
          _showreels = List<Map<String, dynamic>>.from(body['showreels'] ?? []);
          
          // 转换歌曲列表
          final songs = body['songs'] as List? ?? [];
          _tracks = songs.map((song) => Track.fromJson(song)).toList();
          
          // 生成混合项列表
          _generateMixedItems();
          
          _isLoading = false;
        });
      } else {
        throw Exception('获取专辑详情失败: ${response['status']}');
      }
    } catch (e) {
      AppLogger.error('加载专辑详情失败', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  /// 生成混合项列表
  void _generateMixedItems() {
    final List<MixedItem> items = [];
    
    // 为每个作品集添加头部和歌曲项
    for (final showreel in _showreels) {
      // 添加作品集头部
      items.add(MixedItem.reelHeader(showreel));
      
      final songList = List<Map<String, dynamic>>.from(showreel['songList'] ?? []);
      
      // 添加作品集中的歌曲
      for (final songData in songList) {
        final songId = songData['songId'] as String?;
        final songName = songData['songName'] as String? ?? '';
        if (songId != null) {
          // 将字符串ID转换为整数进行匹配
          final songIdInt = int.tryParse(songId);
          if (songIdInt != null) {
            final track = _tracks.firstWhere(
              (track) => track.id == songIdInt,
              orElse: () {
                // 如果在tracks中找不到，创建一个临时Track对象
                return Track(
                  id: songIdInt,
                  name: songName,
                  artists: [],
                  album: Album(
                    id: _albumDetail?['id'] ?? 0,
                    name: _albumDetail?['name'] ?? '',
                    picUrl: _albumDetail?['picUrl'] ?? '',
                  ),
                  duration: 0,
                  popularity: 0.0,
                  fee: 0,
                );
              },
            );
            
            // 创建作品集歌曲项，使用songName作为显示名称
            items.add(MixedItem.reelSong(showreel, track, songName));
          }
        }
      }
    }
    
    // 添加普通歌曲（不在作品集中的歌曲）
    for (final track in _tracks) {
      // 检查歌曲是否已经在作品集中
      bool isInShowreel = false;
      for (final showreel in _showreels) {
        final songList = List<Map<String, dynamic>>.from(showreel['songList'] ?? []);
        if (songList.any((song) {
          final songId = song['songId'] as String?;
          return songId != null && int.tryParse(songId) == track.id;
        })) {
          isInShowreel = true;
          break;
        }
      }
      
      // 如果不在作品集中，添加为普通歌曲项
      if (!isInShowreel) {
        items.add(MixedItem.track(track));
      }
    }
    
    _mixedItems = items;
    
    AppLogger.info('生成混合项列表: ${items.length} 项，其中 ${items.where((item) => item.type == MixedItemType.reelHeader).length} 个作品集头部, ${items.where((item) => item.type == MixedItemType.reelSong).length} 个作品集歌曲');
  }

  /// 播放专辑
  void _playAlbum() {
    if (_tracks.isNotEmpty) {
      final playerService = Provider.of<PlayerService>(context, listen: false);
      playerService.playPlaylist(_tracks, startIndex: 0);
      TopBanner.showSuccess(context, '开始播放专辑');
    }
  }

  /// 播放混合项中的歌曲
  void _playMixedTrack(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    // 获取所有可播放的Track
    final allTracks = _mixedItems
        .where((item) => item.track != null)
        .map((item) => item.track!)
        .toList();
    final trackIndex = allTracks.indexOf(track);
    if (trackIndex >= 0) {
      playerService.setPlaylist(allTracks, trackIndex);
    }
  }

  /// 格式化发布时间
  String _formatPublishTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 显示完整专辑简介
  void _showFullDescription(String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('专辑简介'),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
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

  /// 构建专辑头部信息
  Widget _buildAlbumHeader() {
    if (_albumDetail == null) return const SizedBox.shrink();

    final album = _albumDetail!;
    final publishTime = album['publishTime'] as int? ?? 0;
    final description = album['description'] as String? ?? '';
    final briefDesc = album['briefDesc'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 专辑封面和基本信息
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 专辑封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '${album['picUrl']}?param=240y240',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.album, size: 60),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // 专辑信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album['name'] ?? '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (album['artist'] != null)
                      Text(
                        album['artist']['name'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (publishTime > 0)
                      Text(
                        _formatPublishTime(publishTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${album['size'] ?? 0} 首歌曲',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 播放按钮
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _tracks.isNotEmpty ? _playAlbum : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放全部'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  // TODO: 收藏专辑
                  TopBanner.showInfo(context, '收藏功能待实现');
                },
                icon: const Icon(Icons.favorite_border),
              ),
              IconButton(
                onPressed: () {
                  // TODO: 分享专辑
                  TopBanner.showInfo(context, '分享功能待实现');
                },
                icon: const Icon(Icons.share),
              ),
            ],
          ),
          
          // 专辑描述
          if (description.isNotEmpty || briefDesc.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '专辑简介',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showFullDescription(description.isNotEmpty ? description : briefDesc),
                  child: Icon(
                    Icons.expand_more,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description : briefDesc,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName ?? '专辑详情'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        '加载失败',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAlbumDetail,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : MixedVirtualSongList(
                  items: _mixedItems,
                  onTrackTap: _playMixedTrack,
                  onPlayTap: _playMixedTrack,
                  onMoreTap: _onMoreTap,
                  headerBuilder: () => Column(
                    children: [
                      _buildAlbumHeader(),
                      if (_mixedItems.isNotEmpty) ...[
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                '专辑内容',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_mixedItems.length} 项',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  headerHeight: _calculateHeaderHeight(),
                  enableSearch: true,
                  searchHint: '搜索内容',
                ),
    );
  }

  /// 计算头部高度
  double _calculateHeaderHeight() {
    double height = 10; // 减少基础高度
    
    if (_albumDetail != null) {
      final description = _albumDetail!['description'] as String? ?? '';
      final briefDesc = _albumDetail!['briefDesc'] as String? ?? '';
      if (description.isNotEmpty || briefDesc.isNotEmpty) {
        height += 20; // 减少描述区域高度
      }
    }
    
    height += 15; // 减少专辑内容标题高度
    
    return height;
  }

  /// 更多操作点击处理
  void _onMoreTap(Track track, int index) {
    SongDetailPanel.show(
      context: context,
      track: track,
      index: index,
      onPlay: () => _playMixedTrack(track, index),
      onPlayNext: () {
        // TODO: 实现添加到下一首播放
        TopBanner.showInfo(
          context,
          '下一首播放功能开发中...',
        );
      },
      onAlbumTap: () {
        // 当前已经在专辑页面，显示提示
        TopBanner.showInfo(
          context,
          '您已在专辑 "${track.album.name}" 页面',
        );
      },
      onFavoriteTap: () {
        // TODO: 实现收藏功能
        TopBanner.showInfo(
          context,
          '收藏功能开发中...',
        );
      },
      onDownloadTap: () {
        // TODO: 实现下载功能
        TopBanner.showInfo(
          context,
          '下载功能开发中...',
        );
      },
      onShareTap: () {
        // TODO: 实现分享功能
        TopBanner.showInfo(
          context,
          '分享功能开发中...',
        );
      },
    );
  }
}
