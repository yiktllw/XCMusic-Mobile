import 'package:flutter/material.dart';
import 'package:netease_cloud_music_api/netease_cloud_music_api.dart';
import 'services/api_manager.dart';
import 'services/login_service.dart';
import 'pages/qr_login_page.dart';
import 'pages/debug_page.dart';
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
    AppLogger.config('GlobalConfig实例创建完成，初始化状态: ${globalConfig.isInitialized ? "已初始化" : "未初始化"}');
    
    await globalConfig.initialize();
    AppLogger.config('全局配置管理器初始化成功，当前状态: ${globalConfig.isInitialized ? "已初始化" : "未初始化"}');
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
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userAccountInfo;
  final GlobalConfig _globalConfig = GlobalConfig();
  final LoginService _loginService = LoginService();

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
          _userAccountInfo = userInfo;
        });
        
        // 如果已登录，总是尝试获取最新的用户信息
        if (isLoggedIn) {
          AppLogger.app('已登录状态，正在获取最新用户信息...');
          final userDetail = await _loginService.getSmartUserInfo();
          if (userDetail != null) {
            setState(() {
              _userAccountInfo = _loginService.getSavedUserAccount();
            });
            AppLogger.app('用户信息获取成功');
          } else {
            AppLogger.warning('用户信息获取失败');
          }
        }
      }
    } catch (e) {
      AppLogger.error('加载登录状态失败', e);
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
      // 登录成功，重新加载用户信息
      await _loadLoginStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登录成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 退出登录
  Future<void> _logout() async {
    try {
      await _loginService.clearSavedLoginInfo();
      setState(() {
        _isLoggedIn = false;
        _userAccountInfo = null;
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
      AppLogger.error('退出登录失败', e);
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

  /// 构建统计信息项
  Widget _buildStatItem(String label, String value) {
    final hasBackground = _userAccountInfo?['backgroundUrl'] != null;
    final textColor = hasBackground ? Colors.white : null;
    
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: hasBackground ? Colors.white.withOpacity(0.9) : null,
          ),
        ),
      ],
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                    // 使用用户背景图片作为背景，如果没有则使用默认颜色
                    image: _userAccountInfo?['backgroundUrl'] != null 
                        ? DecorationImage(
                            image: NetworkImage(_userAccountInfo!['backgroundUrl']),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.3),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    color: _userAccountInfo?['backgroundUrl'] == null 
                        ? Colors.green.withOpacity(0.1) 
                        : null,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '已登录',
                        style: TextStyle(
                          fontSize: 18,
                          color: _userAccountInfo?['backgroundUrl'] != null ? Colors.white : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userAccountInfo != null) ...[
                        const SizedBox(height: 16),
                        // 用户头像
                        if (_userAccountInfo!['avatarUrl'] != null)
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(_userAccountInfo!['avatarUrl']),
                            backgroundColor: Colors.grey[300],
                          ),
                        const SizedBox(height: 12),
                        // 用户昵称
                        if (_userAccountInfo!['nickname'] != null)
                          Text(
                            _userAccountInfo!['nickname'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _userAccountInfo?['backgroundUrl'] != null ? Colors.white : null,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // 用户签名
                        if (_userAccountInfo!['signature'] != null && _userAccountInfo!['signature'].toString().isNotEmpty)
                          Text(
                            _userAccountInfo!['signature'],
                            style: TextStyle(
                              fontSize: 14,
                              color: _userAccountInfo?['backgroundUrl'] != null 
                                  ? Colors.white.withOpacity(0.9)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 12),
                        // 用户统计信息
                        Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            if (_userAccountInfo!['followeds'] != null)
                              _buildStatItem('粉丝', _userAccountInfo!['followeds'].toString()),
                            if (_userAccountInfo!['follows'] != null)
                              _buildStatItem('关注', _userAccountInfo!['follows'].toString()),
                            if (_userAccountInfo!['level'] != null)
                              _buildStatItem('等级', 'Lv.${_userAccountInfo!['level']}'),
                            if (_userAccountInfo!['listenSongs'] != null)
                              _buildStatItem('听歌', _userAccountInfo!['listenSongs'].toString()),
                            if (_userAccountInfo!['playlistCount'] != null)
                              _buildStatItem('歌单', _userAccountInfo!['playlistCount'].toString()),
                            if (_userAccountInfo!['eventCount'] != null)
                              _buildStatItem('动态', _userAccountInfo!['eventCount'].toString()),
                          ],
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
