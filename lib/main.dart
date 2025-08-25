import 'package:flutter/material.dart';
import 'services/api_manager.dart';
import 'pages/qr_login_page.dart';
import 'pages/debug_page.dart';
import 'utils/global_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化全局配置管理器
  try {
    await GlobalConfig().initialize();
    print('全局配置管理器初始化成功');
  } catch (e) {
    print('全局配置管理器初始化失败: $e');
  }
  
  // 初始化全局API服务
  try {
    await ApiManager().init();
    print('API服务初始化成功');
  } catch (e) {
    print('API服务初始化失败: $e');
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
  bool _isLoggedIn = false;
  String? _userInfo;
  final GlobalConfig _globalConfig = GlobalConfig();

  @override
  void initState() {
    super.initState();
    _loadLoginStatus();
  }

  /// 加载登录状态
  Future<void> _loadLoginStatus() async {
    try {
      if (_globalConfig.isInitialized) {
        final isLoggedIn = _globalConfig.isLoggedIn();
        final userInfo = _globalConfig.getUserInfo();
        setState(() {
          _isLoggedIn = isLoggedIn;
          _userInfo = userInfo;
        });
      }
    } catch (e) {
      print('加载登录状态失败: $e');
    }
  }

  /// 打开登录页面
  Future<void> _openLogin() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QrLoginPage(),
      ),
    );
    
    if (result != null) {
      // 登录成功，保存到全局配置
      try {
        await _globalConfig.setLoggedIn(true);
        if (result.cookie != null) {
          await _globalConfig.setUserCookie(result.cookie);
        }
        await _globalConfig.setUserInfo({'loginTime': DateTime.now().toString()});
        
        setState(() {
          _isLoggedIn = true;
          _userInfo = '登录成功! Cookie: ${result.cookie?.substring(0, 50) ?? 'N/A'}...';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('保存登录状态失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存登录状态失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 退出登录
  Future<void> _logout() async {
    try {
      await _globalConfig.clearUserData();
      setState(() {
        _isLoggedIn = false;
        _userInfo = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出登录'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('退出登录失败: $e');
    }
  }

  /// 打开调试页面
  void _openDebugPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DebugPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // 调试按钮
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _openDebugPage,
            tooltip: '调试信息',
          ),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: '退出登录',
            )
          else
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _openLogin,
              tooltip: '登录',
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 应用Logo区域
              Icon(
                Icons.music_note,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              Text(
                'XCMusic',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                '音乐播放器',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // 登录状态显示
              if (_isLoggedIn) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '已登录',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userInfo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _userInfo!,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // 未登录状态 - 显示登录按钮
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '未登录',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 扫码登录按钮
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _openLogin,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text(
                            '扫码登录',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
