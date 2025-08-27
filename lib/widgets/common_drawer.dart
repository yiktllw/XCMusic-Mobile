import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import '../services/login_service.dart';

/// 共用的侧栏组件
class CommonDrawer extends StatelessWidget {
  const CommonDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      final loginService = LoginService();
      await loginService.logout();
      if (context.mounted) {
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已退出登录')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出登录失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, size: 20),
            title: const Text('退出登录', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context); // 关闭侧栏
              _logout(context);
            },
          ),
        ],
      ),
    );
  }
}
