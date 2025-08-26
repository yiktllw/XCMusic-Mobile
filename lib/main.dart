import 'package:flutter/material.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';
import 'services/api_manager.dart';
import 'pages/debug_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
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

class XCMusicApp extends StatelessWidget {
  const XCMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XCMusic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'XCMusic'),
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
}
