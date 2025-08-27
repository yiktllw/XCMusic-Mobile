import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';
import 'services/api_manager.dart';
import 'services/player_service.dart';
import 'services/theme_service.dart';
import 'models/playlist.dart';
import 'pages/debug_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/player_page.dart';
import 'pages/playlist_detail_page.dart';
import 'widgets/bottom_player_bar.dart';
import 'widgets/common_drawer.dart';
import 'widgets/playlist_sheet.dart';
import 'utils/global_config.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  AppLogger().initialize();

  // 将应用日志系统接入到API库
  ApiLogManager.setLogger(AppLogger.createApiAdapter());

  // 初始化全局配置管理器
  try {
    AppLogger.app('正在初始化全局配置管理器...');
    final globalConfig = GlobalConfig();

    await globalConfig.initialize();
    AppLogger.config(
      '全局配置管理器初始化成功，当前状态: ${globalConfig.isInitialized ? "已初始化" : "未初始化"}',
    );
  } catch (e) {
    AppLogger.error('全局配置管理器初始化失败', e);
  }

  // 初始化全局API服务
  try {
    await ApiManager().init();
    AppLogger.api('API服务初始化成功');
  } catch (e) {
    AppLogger.error('API服务初始化失败', e);
    // 即使初始化失败也继续运行，让用户看到错误信息
  }

  runApp(const XCMusicApp());
}

class XCMusicApp extends StatefulWidget {
  const XCMusicApp({super.key});

  @override
  State<XCMusicApp> createState() => _XCMusicAppState();
}

class _XCMusicAppState extends State<XCMusicApp> {
  late final PlayerService _playerService;
  late final ThemeService _themeService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _playerService = PlayerService();
    _themeService = ThemeService();
    
    // 等待主题服务初始化完成
    await _themeService.initialize();
    // 初始化播放器
    _playerService.initialize();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _playerService),
        ChangeNotifierProvider.value(value: _themeService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'XCMusic',
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.currentThemeMode,
            home: const MainScaffold(),
            routes: {
              '/player': (context) => const PlayerPageWrapper(),
            },
            onGenerateRoute: (settings) {
              // 为所有页面添加底部播放栏包装
              Widget page;
              switch (settings.name) {
                case '/playlist_detail':
                  final args = settings.arguments as Map<String, dynamic>?;
                  page = PlaylistDetailPageWrapper(
                    playlistId: args?['playlistId'] ?? '',
                    playlistName: args?['playlistName'],
                  );
                  break;
                default:
                  return null;
              }
              return MaterialPageRoute(builder: (context) => page);
            },
          );
        },
      ),
    );
  }
}

/// 主脚手架，包含浮动播放栏
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const HomePage(title: 'XCMusic'),
          // 浮动播放控件
          Positioned(
            left: 12,
            right: 12,
            bottom: 95, // 下移更多
            child: const FloatingPlayerBar(),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = [const HomePageContent(), const ProfilePage()];

  // 底部导航栏项目
  final List<BottomNavigationBarItem> _bottomNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 当在"我的"页面时，使用全屏显示
    if (_currentIndex == 1) {
      return Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: _bottomNavItems,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
        ),
      );
    }

    // 其他页面保持原有的AppBar
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_currentIndex == 0 ? 'XCMusic' : '我的'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: '菜单',
          ),
        ),
        actions: [
          // 调试按钮
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DebugPage()),
              );
            },
            tooltip: '调试信息',
          ),
        ],
      ),
      drawer: const CommonDrawer(),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: _bottomNavItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

/// 播放器页面包装器（不显示底部播放控件）
class PlayerPageWrapper extends StatelessWidget {
  const PlayerPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PlayerPage(),
    );
  }
}

/// 歌单详情页面包装器
class PlaylistDetailPageWrapper extends StatelessWidget {
  final String playlistId;
  final String? playlistName;

  const PlaylistDetailPageWrapper({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PlaylistDetailPage(
            playlistId: playlistId,
            playlistName: playlistName,
          ),
          // 浮动播放控件
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: const FloatingPlayerBar(),
          ),
        ],
      ),
    );
  }
}

/// 通用页面包装器
class PageWrapper extends StatelessWidget {
  final Widget child;

  const PageWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const BottomPlayerBar(),
        ],
      ),
    );
  }
}

/// 浮动播放控件
class FloatingPlayerBar extends StatelessWidget {
  const FloatingPlayerBar({super.key});

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
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: const PlayerPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, playerService, child) {
        final currentTrack = playerService.currentTrack;

        // 如果没有当前播放的歌曲，也显示播放控件但处于禁用状态

        return Container(
          height: 66, // 增大高度以适应更大的图片
          margin: const EdgeInsets.only(top: 20), // 增大上边距来下移控件
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              // 左右滑动切换歌曲
              if (details.primaryVelocity != null && currentTrack != null) {
                if (details.primaryVelocity! > 100) {
                  // 向右滑动，上一首
                  if (playerService.hasPrevious) {
                    playerService.playTrackAt(playerService.currentIndex - 1);
                  }
                } else if (details.primaryVelocity! < -100) {
                  // 向左滑动，下一首
                  if (playerService.hasNext) {
                    playerService.playTrackAt(playerService.currentIndex + 1);
                  }
                }
              }
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: currentTrack != null ? () => _openPlayerPage(context) : null,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        // 专辑封面
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: currentTrack?.album.picUrl.isNotEmpty == true
                                ? Image.network(
                                    currentTrack!.album.picUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.music_note,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.music_note,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                currentTrack?.name ?? '暂无播放',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentTrack?.artists.isNotEmpty == true)
                                Text(
                                  currentTrack!.artists.map((artist) => artist.name).join(', '),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // 播放控件
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: currentTrack != null 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                              onPressed: currentTrack != null ? () => playerService.playPause() : null,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(6),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.playlist_play,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              onPressed: () => _showPlaylist(context, playerService, currentTrack),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(6),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlaylist(BuildContext context, PlayerService playerService, Track? currentTrack) {
    PlaylistSheet.show(context, currentTrack);
  }
}
