// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoPlay = false;
  double _volume = 0.8;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _autoPlay = prefs.getBool('auto_play') ?? false;
          _volume = prefs.getDouble('volume') ?? 0.8;
        });
        
        AppLogger.info('设置已加载: auto_play=$_autoPlay, volume=$_volume');
        return; // 成功加载，退出重试循环
      } catch (e) {
        retryCount++;
        AppLogger.info('加载设置失败 (尝试 $retryCount/$maxRetries): $e');
        
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          AppLogger.info('多次尝试后仍无法加载设置，将使用默认值');
          // 使用默认值
          setState(() {
            _autoPlay = false;
            _volume = 0.8;
          });
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_play', _autoPlay);
        await prefs.setDouble('volume', _volume);

        AppLogger.info('设置已保存: auto_play=$_autoPlay, volume=$_volume');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设置已保存')),
          );
        }
        return; // 成功保存，退出重试循环
      } catch (e) {
        retryCount++;
        AppLogger.info('保存设置失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          AppLogger.info('多次尝试后仍无法保存设置');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('设置保存失败，请稍后重试')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '播放设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('自动播放'),
            subtitle: const Text('启动时自动恢复播放'),
            value: _autoPlay,
            onChanged: (bool value) {
              setState(() {
                _autoPlay = value;
              });
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('音量'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(_volume * 100).round()}%'),
                Slider(
                  value: _volume,
                  onChanged: (double value) {
                    setState(() {
                      _volume = value;
                    });
                  },
                  onChangeEnd: (double value) {
                    _saveSettings();
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '界面设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('主题'),
            subtitle: Consumer<ThemeService>(
              builder: (context, themeService, child) {
                return Text(themeService.getThemeDisplayName());
              },
            ),
            onTap: () => _showThemeDialog(context),
          ),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('XCMusic Mobile v1.0.0'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'XCMusic Mobile',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.music_note),
                children: [
                  const Text('一个基于网易云音乐API的音乐播放器'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    String selectedTheme = themeService.themeMode;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('选择主题'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('浅色主题'),
                leading: Radio<String>(
                  value: 'light',
                  groupValue: selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      selectedTheme = value!;
                    });
                  },
                ),
                trailing: const Icon(Icons.light_mode),
                onTap: () {
                  setState(() {
                    selectedTheme = 'light';
                  });
                },
              ),
              ListTile(
                title: const Text('深色主题'),
                leading: Radio<String>(
                  value: 'dark',
                  groupValue: selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      selectedTheme = value!;
                    });
                  },
                ),
                trailing: const Icon(Icons.dark_mode),
                onTap: () {
                  setState(() {
                    selectedTheme = 'dark';
                  });
                },
              ),
              ListTile(
                title: const Text('跟随系统'),
                leading: Radio<String>(
                  value: 'system',
                  groupValue: selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      selectedTheme = value!;
                    });
                  },
                ),
                trailing: const Icon(Icons.settings),
                onTap: () {
                  setState(() {
                    selectedTheme = 'system';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                themeService.setTheme(selectedTheme);
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}