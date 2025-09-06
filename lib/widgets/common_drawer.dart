import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import '../pages/sleep_timer_page.dart';
import '../services/login_service.dart';
import '../utils/top_banner.dart';

/// 共用的侧栏组件
class CommonDrawer extends StatelessWidget {
  const CommonDrawer({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final loginService = LoginService();
      await loginService.logout();
      if (context.mounted) {
        // 显示成功消息
        TopBanner.showSuccess(
          context,
          '已退出登录',
        );
      }
    } catch (e) {
      if (context.mounted) {
        TopBanner.showError(
          context,
          '退出登录失败: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 32, // 进一步提高侧边栏的层级
      child: Material(
        elevation: 32, // 额外确保Material层级
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'XCMusic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, size: 20),
              title: const Text('设置', style: TextStyle(fontSize: 14)),
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
            ListTile(
              leading: const Icon(Icons.bedtime, size: 20),
              title: const Text('定时关闭', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context); // 关闭侧栏
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SleepTimerPage(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, size: 20),
              title: const Text('退出登录', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context); // 关闭侧栏
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
