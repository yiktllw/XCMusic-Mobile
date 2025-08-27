import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/login_service.dart';
import '../services/api_manager.dart';
import '../services/album_service.dart';
import '../models/album.dart';
import '../utils/global_config.dart';
import '../utils/app_logger.dart';
import '../utils/top_banner.dart';
import 'qr_login_page.dart';
import 'debug_page.dart';
import '../widgets/common_drawer.dart';

/// 个人资料页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userAccountInfo;
  List<Map<String, dynamic>> _userPlaylists = [];
  List<Map<String, dynamic>> _myPlaylists = []; // 我创建的歌单
  List<Map<String, dynamic>> _collectedPlaylists = []; // 收藏的歌单
  List<Album> _albums = []; // 收藏的专辑
  bool _isLoadingPlaylists = false;
  bool _isLoadingAlbums = false;

  // 歌单导航栏相关状态
  int _selectedPlaylistTab = 0; // 0: 创建, 1: 收藏, 2: 专辑

  final GlobalConfig _globalConfig = GlobalConfig();
  final LoginService _loginService = LoginService();
  final AlbumService _albumService = AlbumService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 加载用户数据
  Future<void> _loadUserData() async {
    try {
      if (_globalConfig.isInitialized) {
        final isLoggedIn = _globalConfig.isLoggedIn();
        final userInfo = _globalConfig.getUserInfo();

        setState(() {
          _isLoggedIn = isLoggedIn;
          _userAccountInfo = userInfo;
        });

        if (isLoggedIn) {
          // 获取最新用户信息
          final userDetail = await _loginService.getSmartUserInfo();
          if (userDetail != null) {
            setState(() {
              _userAccountInfo = _loginService.getSavedUserAccount();
            });
          }

          // 获取用户歌单
          await _loadUserPlaylists();
          // 获取用户收藏的专辑
          await _loadUserAlbums();
        }
      }
    } catch (e) {
      AppLogger.error('加载用户数据失败', e);
    }
  }

  /// 加载用户收藏的专辑
  Future<void> _loadUserAlbums({bool latest = false}) async {
    if (!_isLoggedIn) return;

    setState(() {
      _isLoadingAlbums = true;
    });

    try {
      final response = await _albumService.getAllSubscribedAlbums(
        latest: latest,
      );

      setState(() {
        _albums = response;
      });
    } catch (e) {
      AppLogger.error('获取用户专辑失败', e);
    } finally {
      setState(() {
        _isLoadingAlbums = false;
      });
    }
  }

  /// 加载用户歌单
  Future<void> _loadUserPlaylists({bool latest = false}) async {
    if (!_isLoggedIn || _userAccountInfo == null) return;

    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      final userId = _userAccountInfo!['userId'];
      final userCookie = _globalConfig.getUserCookie();
      if (userId != null) {
        String? timestamp;
        if (latest) {
          timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        } else {
          timestamp = null;
        }
        final result = await ApiManager().api.userPlaylist(
          uid: userId.toString(),
          limit: 50,
          timestamp: timestamp,
          cookie: userCookie,
        );

        if (result['status'] == 200 && result['body'] != null) {
          final body = result['body'] as Map<String, dynamic>;
          if (body['code'] == 200) {
            final playlists = body['playlist'] as List?;
            if (playlists != null) {
              final allPlaylists = playlists.cast<Map<String, dynamic>>();
              final myPlaylists = <Map<String, dynamic>>[];
              final collectedPlaylists = <Map<String, dynamic>>[];

              // 分离我的歌单和收藏的歌单
              for (final playlist in allPlaylists) {
                final subscribed = playlist['subscribed'] as bool? ?? false;

                if (!subscribed) {
                  myPlaylists.add(playlist);
                } else {
                  collectedPlaylists.add(playlist);
                }
              }

              setState(() {
                _userPlaylists = allPlaylists;
                _myPlaylists = myPlaylists;
                _collectedPlaylists = collectedPlaylists;
              });
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('获取用户歌单失败', e);
    } finally {
      setState(() {
        _isLoadingPlaylists = false;
      });
    }
  }

  /// 打开登录页面
  Future<void> _openLogin() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const QrLoginPage()));

    if (result != null) {
      // 登录成功，重新加载用户数据
      await _loadUserData();

      if (mounted) {
        TopBanner.showSuccess(
          context,
          '登录成功！',
        );
      }
    }
  }

  /// 刷新所有数据
  Future<void> _refreshAllData() async {
    if (!_isLoggedIn) return;

    setState(() {
      _isLoadingPlaylists = true;
      _isLoadingAlbums = true;
    });

    try {
      await Future.wait([_loadUserPlaylists(), _loadUserAlbums()]);
    } finally {
      if (mounted) {
        TopBanner.showSuccess(
          context,
          '已刷新数据',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  /// 显示刷新菜单
  void _showRefreshMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('刷新数据'),
                onTap: () {
                  Navigator.pop(context);
                  _refreshAllData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建歌单导航栏
  Widget _buildPlaylistNavBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[900] 
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // 创建标签
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlaylistTab = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedPlaylistTab == 0
                              ? (Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[800] 
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _selectedPlaylistTab == 0
                              ? [
                                  BoxShadow(
                                    color: (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.black.withValues(alpha: 0.3) 
                                        : Colors.black.withValues(alpha: 0.1)),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '创建',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlaylistTab == 0
                                    ? (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white 
                                        : Colors.black87)
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.grey[400] 
                                        : Colors.grey[600]),
                              ),
                            ),
                            if (_myPlaylists.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${_myPlaylists.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPlaylistTab == 0
                                      ? (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[300] 
                                          : Colors.black54)
                                      : (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[500] 
                                          : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 收藏标签
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlaylistTab = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedPlaylistTab == 1
                              ? (Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[800] 
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _selectedPlaylistTab == 1
                              ? [
                                  BoxShadow(
                                    color: (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.black.withValues(alpha: 0.3) 
                                        : Colors.black.withValues(alpha: 0.1)),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '收藏',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlaylistTab == 1
                                    ? (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white 
                                        : Colors.black87)
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.grey[400] 
                                        : Colors.grey[600]),
                              ),
                            ),
                            if (_collectedPlaylists.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${_collectedPlaylists.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPlaylistTab == 1
                                      ? (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[300] 
                                          : Colors.black54)
                                      : (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[500] 
                                          : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 专辑标签
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlaylistTab = 2;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedPlaylistTab == 2
                              ? (Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[800] 
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _selectedPlaylistTab == 2
                              ? [
                                  BoxShadow(
                                    color: (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.black.withValues(alpha: 0.3) 
                                        : Colors.black.withValues(alpha: 0.1)),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '专辑',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedPlaylistTab == 2
                                    ? (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white 
                                        : Colors.black87)
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.grey[400] 
                                        : Colors.grey[600]),
                              ),
                            ),
                            if (_albums.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${_albums.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedPlaylistTab == 2
                                      ? (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[300] 
                                          : Colors.black54)
                                      : (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.grey[500] 
                                          : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 更多按钮
          Container(
            height: 40, // 明确设置高度以匹配标签栏按钮
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[800] 
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.more_horiz, 
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black54,
              ),
              onPressed: _showRefreshMenu,
              tooltip: '更多操作',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计信息项
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  /// 构建歌单项
  Widget _buildPlaylistItem(Map<String, dynamic> playlist) {
    final name = playlist['name'] ?? '未知歌单';
    final trackCount = playlist['trackCount'] ?? 0;
    final playCount = playlist['playCount'] ?? 0;
    final coverImgUrl = playlist['coverImgUrl'] ?? '';
    final description = playlist['description'] ?? '';

    return _buildUnifiedListItem(
      title: name,
      subtitle: description,
      imageUrl: coverImgUrl,
      fallbackIcon: Icons.music_note,
      details: [
        _buildListDetail(Icons.music_note, '$trackCount首'),
        _buildListDetail(Icons.play_arrow, _formatPlayCount(playCount)),
      ],
      onTap: () {
        final playlistId = playlist['id'];
        if (playlistId != null) {
          Navigator.pushNamed(
            context,
            '/playlist_detail',
            arguments: {
              'playlistId': playlistId.toString(),
              'playlistName': playlist['name'],
            },
          );
        } else {
          AppLogger.warning('歌单ID为空，无法跳转到详情页面');
          TopBanner.showError(
            context,
            '歌单信息异常，无法打开',
          );
        }
      },
    );
  }

  /// 格式化播放次数
  String _formatPlayCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else if (count < 100000000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
  }

  /// 构建专辑项
  Widget _buildAlbumItem(Album album) {
    return _buildUnifiedListItem(
      title: album.name,
      subtitle: album.artistNames,
      imageUrl: "${album.picUrl}?param=100y100",
      fallbackIcon: Icons.album,
      details: [
        _buildListDetail(Icons.music_note, '${album.size}首'),
        _buildListDetail(Icons.calendar_today, _formatSubTime(album.subTime)),
      ],
      onTap: () {
        TopBanner.showInfo(
          context,
          '点击了专辑: ${album.name}',
        );
      },
    );
  }

  /// 格式化订阅时间
  String _formatSubTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}周前';
    } else if (difference.inDays < 365) {
      return '${difference.inDays ~/ 30}个月前';
    } else {
      return '${difference.inDays ~/ 365}年前';
    }
  }

  /// 构建统一的列表项
  Widget _buildUnifiedListItem({
    required String title,
    required String subtitle,
    required String imageUrl,
    required IconData fallbackIcon,
    required List<Widget> details,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 图片区域
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          cacheWidth: 84,
                          cacheHeight: 84,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildPlaceholder(fallbackIcon);
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(fallbackIcon),
                        )
                      : _buildPlaceholder(fallbackIcon),
                ),
                const SizedBox(width: 8),
                // 文本区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      // 详细信息行
                      Wrap(spacing: 8, runSpacing: 2, children: details),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建占位符
  Widget _buildPlaceholder(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 18, color: Colors.grey[500]),
    );
  }

  /// 构建列表详情项
  Widget _buildListDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? _buildLoggedInView() : _buildNotLoggedInView();
  }

  /// 构建已登录视图 - 普通模式
  Widget _buildLoggedInView() {
    return Scaffold(
      // 添加AppBar以便侧栏正常工作
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
              ? Brightness.light 
              : Brightness.dark,
          statusBarBrightness: Theme.of(context).brightness,
        ),
        title: const Text('我的'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white 
            : Colors.black,
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
                MaterialPageRoute(
                  builder: (context) => const DebugPage(),
                ),
              );
            },
            tooltip: '调试信息',
          ),
        ],
      ),
      // 使用共用侧栏
      drawer: const CommonDrawer(),
      body: SafeArea(
        child: CustomScrollView(
          // 添加物理效果优化
          physics: const BouncingScrollPhysics(),
          // 添加缓存范围
          cacheExtent: 500,
          slivers: [
            // 用户信息头部
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // 用户头像
                    if (_userAccountInfo?['avatarUrl'] != null)
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(
                          _userAccountInfo!['avatarUrl'],
                        ),
                        backgroundColor: Colors.grey[300],
                      ),
                    const SizedBox(height: 12),

                    // 用户昵称
                    if (_userAccountInfo?['nickname'] != null)
                      Text(
                        _userAccountInfo!['nickname'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // 用户签名
                    if (_userAccountInfo?['signature'] != null &&
                        _userAccountInfo!['signature'].toString().isNotEmpty)
                      Text(
                        _userAccountInfo!['signature'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 16),

                    // 用户统计信息
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        if (_userAccountInfo?['followeds'] != null)
                          _buildStatItem(
                            '粉丝',
                            _userAccountInfo!['followeds'].toString(),
                          ),
                        if (_userAccountInfo?['follows'] != null)
                          _buildStatItem(
                            '关注',
                            _userAccountInfo!['follows'].toString(),
                          ),
                        if (_userAccountInfo?['level'] != null)
                          _buildStatItem(
                            '等级',
                            'Lv.${_userAccountInfo!['level']}',
                          ),
                        if (_userAccountInfo?['listenSongs'] != null)
                          _buildStatItem(
                            '听歌',
                            _userAccountInfo!['listenSongs'].toString(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 歌单区域背景
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const SizedBox(height: 8),
              ),
            ),

            // 歌单导航栏
            if (_userPlaylists.isNotEmpty || _isLoadingPlaylists)
              SliverToBoxAdapter(child: _buildPlaylistNavBar()),

            // 当前选中的内容列表
            if (_selectedPlaylistTab == 0 || _selectedPlaylistTab == 1)
              // 歌单列表
              if (_isLoadingPlaylists)
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                )
              else if (_selectedPlaylistTab == 0)
                // 创建的歌单
                if (_myPlaylists.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Text(
                            '暂无创建的歌单',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: _myPlaylists.length,
                    itemBuilder: (context, index) {
                      return Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: _buildPlaylistItem(_myPlaylists[index]),
                      );
                    },
                  )
              else if (_collectedPlaylists.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 32,
                      ),
                      child: Center(
                        child: Text(
                          '暂无收藏的歌单',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _collectedPlaylists.length,
                  itemBuilder: (context, index) {
                    return Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: _buildPlaylistItem(_collectedPlaylists[index]),
                    );
                  },
                )
            else if (_isLoadingAlbums)
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              )
            else if (_albums.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: Center(
                      child: Text(
                        '暂无收藏的专辑',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: _albums.length,
                itemBuilder: (context, index) {
                  return Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildAlbumItem(_albums[index]),
                  );
                },
              ),

            // 完全无歌单的情况
            if (_userPlaylists.isEmpty && !_isLoadingPlaylists)
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        '暂无歌单',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

            // 底部安全区域
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                height: 100, // 增加底部空白从20到100
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建未登录视图
  Widget _buildNotLoggedInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                '未登录',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '登录后可查看个人信息和歌单',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 扫码登录按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('扫码登录', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }
}
