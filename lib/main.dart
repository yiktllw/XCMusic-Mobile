import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';
import 'services/api_manager.dart';
import 'services/player_service.dart';
import 'services/theme_service.dart';
import 'services/likelist_service.dart';
import 'services/sleep_timer_service.dart';
import 'services/navigation_service.dart';
import 'models/playlist.dart';
import 'pages/debug_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/player_page.dart';
import 'pages/playlist_detail_page.dart';
import 'pages/album_detail_page.dart';
import 'pages/search_page.dart';
import 'pages/search_result_page.dart';
import 'pages/qr_login_page.dart';
import 'pages/settings_page.dart';
import 'pages/recommend_songs_page.dart';
import 'pages/sleep_timer_page.dart';
import 'pages/sensor_permission_page.dart';
import 'widgets/common_drawer.dart';
import 'widgets/playlist_sheet.dart';
import 'widgets/scrolling_text.dart';
import 'widgets/auto_floating_player_wrapper.dart';
import 'utils/global_config.dart';
import 'utils/app_logger.dart';
import 'config/search_bar_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  AppLogger().initialize();

  // 将应用日志系统接入到API库
  ApiLogManager.setLogger(AppLogger.createApiAdapter());

  // 初始化 AudioService
  try {
    AppLogger.app('正在初始化音频服务...');
    await AudioService.init(
      builder: () => AudioPlayerHandler.instance,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.xcmusic.audio',
        androidNotificationChannelName: 'XCMusic Audio Service',
        androidNotificationOngoing: false, // 改为false，避免强制前台
        androidStopForegroundOnPause: false, // 暂停时不停止前台服务
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        // 增加MediaBrowserService支持
        androidBrowsableRootExtras: {
          'android.service.media.extra.RECENT': true,
          'android.service.media.extra.OFFLINE': true,
        },
        // 添加前台服务类型
        androidResumeOnClick: true,
      ),
    );
    AppLogger.app('音频服务初始化成功');
  } catch (e) {
    AppLogger.error('音频服务初始化失败', e);
  }

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
  PlayerService? _playerService;
  ThemeService? _themeService;
  SleepTimerService? _sleepTimerService;
  bool _isThemeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _playerService = PlayerService();
      _themeService = ThemeService();
      _sleepTimerService = SleepTimerService();
      
      // 首先同步初始化主题服务，避免主题切换闪烁
      await _themeService!.initialize().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warning('主题服务初始化超时，使用默认设置');
        },
      );
      
      // 主题初始化完成后更新界面
      if (mounted) {
        setState(() {
          _isThemeInitialized = true;
        });
      }
      
      // 后台初始化播放器（不阻塞界面显示）
      _initializePlayerAsync();
      
      // 初始化喜欢列表服务
      _initializeLikelistAsync();
      
      // 初始化定时关闭服务
      _initializeSleepTimerAsync();
      
      AppLogger.info('核心服务初始化完成');
    } catch (e) {
      AppLogger.error('服务初始化失败，使用默认配置: $e');
      // 即使失败也要显示界面
      if (mounted) {
        setState(() {
          _isThemeInitialized = true;
        });
      }
    }
  }
  
  Future<void> _initializePlayerAsync() async {
    try {
      await _playerService!.initialize().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('播放器初始化超时，跳过状态恢复');
        },
      );
      AppLogger.info('播放器服务初始化完成');
    } catch (e) {
      AppLogger.error('播放器初始化失败', e);
    }
  }
  
  Future<void> _initializeLikelistAsync() async {
    try {
      await LikelistService().initializeLikelistOnStartup();
      AppLogger.info('喜欢列表服务初始化完成');
    } catch (e) {
      AppLogger.error('喜欢列表服务初始化失败', e);
    }
  }
  
  Future<void> _initializeSleepTimerAsync() async {
    try {
      await _sleepTimerService!.initialize();
      // 设置播放器服务引用，让定时关闭服务可以控制播放
      _sleepTimerService!.setPlayerService(_playerService!);
      AppLogger.info('定时关闭服务初始化完成');
    } catch (e) {
      AppLogger.error('定时关闭服务初始化失败', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在主题初始化完成之前显示开屏界面，避免主题切换闪烁
    if (!_isThemeInitialized) {
      // 根据系统主题决定背景颜色，减少视觉冲击
      final brightness = MediaQuery.platformBrightnessOf(context);
      final backgroundColor = brightness == Brightness.dark ? Colors.black : Colors.white;
      final logoColor = brightness == Brightness.dark ? Colors.white : Colors.black;
      
      return MaterialApp(
        home: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: SvgPicture.asset(
              'assets/icons/xcmusic_modular.svg',
              width: 80,
              height: 80,
              colorFilter: ColorFilter.mode(logoColor, BlendMode.srcIn),
              semanticsLabel: 'XCMusic Logo',
            ),
          ),
        ),
      );
    }
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _playerService ?? PlayerService()),
        ChangeNotifierProvider.value(value: _themeService ?? ThemeService()),
        ChangeNotifierProvider.value(value: _sleepTimerService ?? SleepTimerService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'XCMusic',
            navigatorKey: NavigationService.navigatorKey,
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.currentThemeMode,
            home: const MainScaffold(),
            routes: AutoRouteBuilder.createRoutesMap({
              '/player': (context) => const PlayerPage(),
              '/search': (context) => const SearchPage(),
              '/debug': (context) => const DebugPage(),
              '/qr_login': (context) => const QrLoginPage(),
              '/settings': (context) => const SettingsPage(),
              '/sleep-timer': (context) => const SleepTimerPage(),
              '/sensor_permission': (context) => const SensorPermissionPage(),
            }),
            onGenerateRoute: (settings) {
              // 自动为所有页面添加浮动播放栏包装
              Widget page;
              switch (settings.name) {
                case '/playlist_detail':
                  final args = settings.arguments as Map<String, dynamic>?;
                  page = PlaylistDetailPage(
                    playlistId: args?['playlistId'] ?? '',
                    playlistName: args?['playlistName'],
                  );
                  break;
                case '/album_detail':
                  final args = settings.arguments as Map<String, dynamic>?;
                  page = AlbumDetailPage(
                    albumId: args?['albumId'] ?? '',
                    albumName: args?['albumName'],
                  );
                  break;
                case '/recommend_songs':
                  final args = settings.arguments as Map<String, dynamic>?;
                  final recommendedSongs = args?['recommendedSongs'] as List<Track>? ?? [];
                  page = RecommendSongsPage(
                    recommendedSongs: recommendedSongs,
                  );
                  break;
                case '/search_result':
                  final args = settings.arguments as Map<String, dynamic>?;
                  final query = args?['query'] as String? ?? '';
                  page = SearchResultPage(query: query);
                  break;
                default:
                  return null;
              }
              
              // 自动包装浮动播放栏
              return AutoWrappedPageRoute(
                builder: (context) => page,
                settings: settings,
                routeName: settings.name,
              );
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
      drawer: const CommonDrawer(), // 将Drawer移到最外层
      body: Stack(
        children: [
          const HomePage(title: 'XCMusic'),
          // 浮动播放控件
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 64, // 适应安全区域
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

  Future<bool> _onWillPop() async {
    if (_currentIndex == 1) {
      // 在"我的"页面时，返回主页
      setState(() {
        _currentIndex = 0;
      });
      return false; // 阻止默认的返回行为
    } else {
      // 在"主页"时，最小化程序
      SystemNavigator.pop();
      return false; // 阻止默认的返回行为
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 阻止默认的返回行为
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
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
    // 主页也使用全屏显示，确保浮动播放控件在侧栏下方
    if (_currentIndex == 0) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/search');
            },
            child: Container(
              height: SearchBarConfig.height,
              padding: SearchBarConfig.horizontalPadding,
              decoration: SearchBarConfig.getContainerDecoration(context),
              child: Row(
                children: [
                  SearchBarConfig.getSearchIcon(context),
                  SizedBox(width: SearchBarConfig.iconTextSpacing),
                  Expanded(
                    child: Text(
                      '搜索音乐、歌手、专辑',
                      style: SearchBarConfig.getHintTextStyle(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                // 向上查找包含drawer的Scaffold的Element
                Element? scaffoldElement;
                context.visitAncestorElements((element) {
                  final widget = element.widget;
                  if (widget is Scaffold && widget.drawer != null) {
                    scaffoldElement = element;
                    return false; // 找到包含drawer的Scaffold，停止查找
                  }
                  return true; // 继续向上查找
                });
                
                if (scaffoldElement != null) {
                  // 直接从找到的Element获取ScaffoldState
                  final scaffoldState = (scaffoldElement as StatefulElement).state as ScaffoldState;
                  scaffoldState.openDrawer();
                } else {
                  debugPrint('未找到包含drawer的Scaffold');
                }
              },
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

    // 其他页面保持原有的AppBar (这部分代码现在不会被执行，但保留以防后续添加更多页面)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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

/// 浮动播放控件
class FloatingPlayerBar extends StatefulWidget {
  const FloatingPlayerBar({super.key});

  @override
  State<FloatingPlayerBar> createState() => _FloatingPlayerBarState();
}

class _FloatingPlayerBarState extends State<FloatingPlayerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  double _dragOffset = 0.0;
  double _currentOffset = 0.0; // 当前实际偏移值，用于跟手滑动
  Track? _targetTrack; // 目标歌曲
  bool _isNext = true; // 滑动方向

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateSwipe(bool isNext) {
    final targetValue = isNext ? -1.0 : 1.0;
    _slideAnimation = Tween<double>(
      begin: _currentOffset,
      end: targetValue,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _animationController.reset();
    _animationController.forward().then((_) {
      // 动画完成后重置
      _currentOffset = 0.0;
      _targetTrack = null;
    });
  }

  void _resetAnimation() {
    _slideAnimation = Tween<double>(
      begin: _currentOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
    
    _animationController.reset();
    _animationController.forward().then((_) {
      _currentOffset = 0.0;
      _targetTrack = null;
    });
  }

  Track? _getTargetTrack(PlayerService playerService, bool isNext) {
    if (isNext && playerService.hasNext) {
      final nextIndex = playerService.currentIndex + 1;
      if (nextIndex < playerService.playlist.length) {
        return playerService.playlist[nextIndex];
      }
    } else if (!isNext && playerService.hasPrevious) {
      final prevIndex = playerService.currentIndex - 1;
      if (prevIndex >= 0) {
        return playerService.playlist[prevIndex];
      }
    }
    return null;
  }

  Widget _buildTrackInfo(BuildContext context, Track? track, bool isTarget) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: !isTarget && track != null ? () => _openPlayerPage(context) : null,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
        decoration: BoxDecoration(
          color: isTarget 
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
              : Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // 专辑封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: track?.album.picUrl.isNotEmpty == true
                    ? Image.network(
                        '${track!.album.picUrl}?param=100y100',
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
                  ScrollingText(
                    text: track?.name ?? '暂无播放',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: isTarget 
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                  ),
                  if (track?.artists.isNotEmpty == true)
                    ScrollingText(
                      text: '${track!.artists.map((artist) => artist.name).join(', ')} · ${track.album.name}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, playerService, child) {
        final currentTrack = playerService.currentTrack;

        // 如果没有当前播放的歌曲，也显示播放控件但处于禁用状态

        return Container(
          height: 60, // 增大高度以适应更大的图片
          // margin: const EdgeInsets.only(bottom: 20), // 增大上边距来下移控件
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), // 降低阴影强度
                blurRadius: 8, // 减小模糊半径
                offset: const Offset(0, 2), // 减小偏移
              ),
            ],
          ),
          child: GestureDetector(
            onHorizontalDragStart: (details) {
              _dragOffset = 0.0;
              _currentOffset = 0.0;
              _targetTrack = null;
            },
            onHorizontalDragUpdate: (details) {
              // 实时更新滑动位置，完全跟手
              setState(() {
                _dragOffset += details.delta.dx;
                final screenWidth = MediaQuery.of(context).size.width;
                final maxOffset = screenWidth * 0.5; // 最大滑动距离
                _currentOffset = (_dragOffset / maxOffset).clamp(-1.0, 1.0);
                
                // 确定滑动方向和目标歌曲
                if (_currentOffset.abs() > 0.1) {
                  _isNext = _currentOffset < 0;
                  _targetTrack = _getTargetTrack(playerService, _isNext);
                } else {
                  _targetTrack = null;
                }
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final slideThreshold = 0.3; // 滑动阈值
              
              // 检查滑动距离和速度
              bool shouldSwitch = _currentOffset.abs() > slideThreshold || velocity.abs() > 500;
              
              if (shouldSwitch && currentTrack != null) {
                bool isNext = _currentOffset < 0 || velocity < 0;
                
                if (isNext && playerService.hasNext) {
                  // 向左滑动，下一首
                  _animateSwipe(true);
                  playerService.playTrackAt(playerService.currentIndex + 1);
                } else if (!isNext && playerService.hasPrevious) {
                  // 向右滑动，上一首
                  _animateSwipe(false);
                  playerService.playTrackAt(playerService.currentIndex - 1);
                } else {
                  // 没有下一首/上一首，回弹动画
                  _resetAnimation();
                }
              } else {
                // 滑动距离不够，回弹到原位
                _resetAnimation();
              }
              
              // 重置拖拽偏移
              _dragOffset = 0.0;
            },
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                // 在动画期间使用动画值，在拖拽期间使用当前偏移值
                final displayOffset = _animationController.isAnimating ? _slideAnimation.value : _currentOffset;
                
                return Stack(
                  children: [
                    // 固定的播放控件容器
                    Positioned(
                      right: 4, // 进一步减少右边距
                      top: 8,
                      bottom: 8,
                      width: 60, // 进一步减少宽度
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: currentTrack != null ? () => playerService.playPause() : null,
                                child: SizedBox(
                                  width: 28, // 固定宽度，无最小宽度
                                  height: 28, // 固定高度
                                  child: Icon(
                                    playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: currentTrack != null 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  width: 28, // 固定宽度，无最小宽度
                                  height: 28, // 固定高度
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
                    ),
                    // 可滑动的歌曲信息容器
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: 64, // 调整为播放控件留出空间
                      child: ClipRect(
                        child: Stack(
                          children: [
                            // 当前歌曲
                            Transform.translate(
                              offset: Offset(displayOffset * 200, 0), // 减小滑动距离
                              child: Opacity(
                                opacity: 1.0 - (displayOffset.abs() * 0.3), // 滑动时透明度变化
                                child: _buildTrackInfo(context, currentTrack, false),
                              ),
                            ),
                            // 目标歌曲（从右侧填充）
                            if (_targetTrack != null && displayOffset.abs() > 0.1)
                              Transform.translate(
                                offset: Offset(
                                  displayOffset > 0 
                                    ? (displayOffset - 1) * 200  // 从左侧进入
                                    : (displayOffset + 1) * 200, // 从右侧进入
                                  0
                                ),
                                child: Opacity(
                                  opacity: displayOffset.abs() * 0.8, // 目标歌曲淡入效果
                                  child: _buildTrackInfo(context, _targetTrack, true),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
