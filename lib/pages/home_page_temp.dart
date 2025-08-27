import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../models/playlist.dart';
import 'settings_page.dart';

/// 主页内容页面
class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  void _testPlayerService(BuildContext context) {
    final playerService = Provider.of<PlayerService>(context, listen: false);
    
    // 创建测试歌曲数据 - 使用真实的歌曲ID
    final testTracks = [
      Track(
        id: 411214279, // 周杰伦 - 告白气球
        name: '告白气球',
        artists: [Artist(id: 6452, name: '周杰伦')],
        album: Album(
          id: 34710950,
          name: '周杰伦的床边故事',
          picUrl: 'https://p2.music.126.net/YJ4h8K_GhNznkZCjZ_YVvA==/18644672579235726.jpg',
        ),
        duration: 203000,
        popularity: 100,
        fee: 8,
      ),
      Track(
        id: 1345848098, // 毛不易 - 消愁
        name: '消愁',
        artists: [Artist(id: 12138269, name: '毛不易')],
        album: Album(
          id: 75438651,
          name: '平凡的一天',
          picUrl: 'https://p2.music.126.net/vmCcDvD1H04e9gm97xsCqg==/109951163350929740.jpg',
        ),
        duration: 234000,
        popularity: 95,
        fee: 8,
      ),
    ];
    
    // 设置播放列表并开始播放
    playerService.setPlaylist(testTracks, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 添加侧栏
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Text(
                '设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context); // 关闭侧栏
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // 添加顶部工具栏
      appBar: AppBar(
        title: const Text('XC Music'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: '设置',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text(
              'XCMusic',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '移动端音乐播放器',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _testPlayerService(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('测试播放'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<PlayerService>(
              builder: (context, playerService, child) {
                if (playerService.currentTrack == null) {
                  return const Text('暂无播放内容');
                }
                return Column(
                  children: [
                    Text(
                      '正在播放: ${playerService.currentTrack!.name}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      '歌手: ${playerService.currentTrack!.artists.map((a) => a.name).join(', ')}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
