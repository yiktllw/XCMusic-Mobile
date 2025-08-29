import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../services/player_service.dart';
import '../widgets/virtual_song_list.dart';

/// 推荐歌曲页面
class RecommendSongsPage extends StatefulWidget {
  final List<Track> recommendedSongs;

  const RecommendSongsPage({
    super.key,
    required this.recommendedSongs,
  });

  @override
  State<RecommendSongsPage> createState() => _RecommendSongsPageState();
}

class _RecommendSongsPageState extends State<RecommendSongsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('每日推荐 (${widget.recommendedSongs.length}首)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 播放全部按钮
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            onPressed: () => _playAll(context),
            tooltip: '播放全部',
          ),
        ],
      ),
      body: Column(
        children: [
          // 歌曲列表
          Expanded(
            child: VirtualSongList(
              tracks: widget.recommendedSongs,
              onTrackTap: _onTrackTap,
              onMoreTap: _onMoreTap,
              currentPlayingId: _getCurrentPlayingId(context),
              enableSearch: true,
              searchHint: '搜索推荐歌曲',
            ),
          ),
        ],
      ),
    );
  }

  /// 获取当前播放的歌曲ID
  int? _getCurrentPlayingId(BuildContext context) {
    final playerService = Provider.of<PlayerService>(context);
    return playerService.currentTrack?.id;
  }

  /// 播放全部
  void _playAll(BuildContext context) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    if (widget.recommendedSongs.isNotEmpty) {
      playerService.setPlaylist(widget.recommendedSongs, 0);
      playerService.play();
    }
  }

  /// 歌曲点击处理
  void _onTrackTap(Track track, int index) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    playerService.setPlaylist(widget.recommendedSongs, index);
    playerService.play();
  }

  /// 更多操作处理
  void _onMoreTap(Track track, int index) {
    // TODO: 实现更多操作菜单
    // 可以显示底部菜单包含：添加到歌单、下载、分享等选项
  }
}
