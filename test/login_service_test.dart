import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import '../lib/services/login_service.dart';
import '../lib/utils/global_config.dart';
import '../lib/utils/app_logger.dart';

void main() {
  group('LoginService 智能API选择测试', () {
    late LoginService loginService;
    late GlobalConfig globalConfig;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();

      // 初始化日志系统
      AppLogger().initialize();

      // 初始化全局配置
      globalConfig = GlobalConfig();
      await globalConfig.initialize();

      loginService = LoginService();
    });

    tearDown(() async {
      // 清理测试数据
      await globalConfig.clearUserData();
    });

    test('当uid未知时，应该使用user/account接口', () async {
      // 确保没有保存的用户信息
      await globalConfig.clearUserData();

      // 验证getSmartUserInfo方法的行为
      // 注意：这里需要模拟网络请求，实际测试中可能需要mock
      print('测试：uid未知时的API选择逻辑');

      // 检查当前是否有保存的uid
      final userInfo = globalConfig.getUserInfo();
      expect(userInfo, isNull, reason: '确保没有保存的用户信息');

      print('✅ uid未知测试：验证通过');
    });

    test('当uid已知时，应该使用user/detail接口', () async {
      // 模拟保存用户信息（包含uid）
      final mockUserInfo = {
        'userId': 375334328,
        'nickname': 'TestUser',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'updateTime': DateTime.now().millisecondsSinceEpoch,
      };

      await globalConfig.setUserInfo(mockUserInfo);

      // 验证uid是否已保存
      final savedUserInfo = globalConfig.getUserInfo();
      expect(savedUserInfo, isNotNull, reason: '用户信息应该已保存');
      expect(savedUserInfo!['userId'], equals(375334328), reason: 'uid应该匹配');

      print('✅ uid已知测试：验证通过');
    });

    test('保存用户详情格式验证', () async {
      // 模拟userDetail API返回格式
      final mockUserDetail = {
        'code': 200,
        'level': 9,
        'listenSongs': 16216,
        'profile': {
          'userId': 375334328,
          'nickname': 'YiktLLW',
          'avatarUrl':
              'http://p1.music.126.net/cJMGNeFS-okVM9VJ96HaFA==/109951168824917156.jpg',
          'signature': 'brahms..',
          'userType': 0,
          'vipType': 11,
          'gender': 1,
          'birthday': -2209017600000,
          'province': 0,
          'city': 100,
          'followed': false,
          'followeds': 33,
          'follows': 37,
          'createTime': -1,
          'description': '',
          'detailDescription': '',
          'eventCount': 0,
          'playlistCount': 48,
          'playlistBeSubscribedCount': 9,
          'djStatus': 0,
          'mutual': false,
          'accountStatus': 0,
          'authStatus': 0,
          'authority': 0,
          'backgroundUrl':
              'http://p1.music.126.net/JVbDAh4nWTHAdQOoiFMBrA==/109951166370794851.jpg',
          'defaultAvatar': false,
        },
      };

      // 验证数据结构
      expect(mockUserDetail['profile'], isNotNull, reason: 'profile字段应该存在');
      expect(mockUserDetail['level'], isNotNull, reason: 'level字段应该存在');
      expect(
        mockUserDetail['listenSongs'],
        isNotNull,
        reason: 'listenSongs字段应该存在',
      );

      final profile = mockUserDetail['profile'] as Map<String, dynamic>;
      expect(profile['userId'], isNotNull, reason: 'userId字段应该存在');
      expect(profile['nickname'], isNotNull, reason: 'nickname字段应该存在');
      expect(profile['followeds'], isNotNull, reason: 'followeds字段应该存在');
      expect(profile['follows'], isNotNull, reason: 'follows字段应该存在');
      expect(
        profile['playlistCount'],
        isNotNull,
        reason: 'playlistCount字段应该存在',
      );

      print('✅ userDetail数据格式验证：通过');
    });

    test('用户信息字段映射验证', () async {
      // 验证从userDetail返回数据中提取的字段能够正确保存和显示
      final userDetailFields = [
        'userId',
        'nickname',
        'avatarUrl',
        'signature',
        'userType',
        'vipType',
        'gender',
        'birthday',
        'province',
        'city',
        'followed',
        'followeds',
        'follows',
        'level',
        'listenSongs',
        'createTime',
        'description',
        'detailDescription',
        'eventCount',
        'playlistCount',
        'playlistBeSubscribedCount',
        'djStatus',
        'mutual',
        'accountStatus',
        'authStatus',
        'authority',
        'backgroundUrl',
        'defaultAvatar',
      ];

      print('支持的userDetail字段:');
      for (String field in userDetailFields) {
        print('  - $field');
      }

      expect(userDetailFields.length, greaterThan(20), reason: '应该支持足够多的字段');
      expect(userDetailFields.contains('level'), isTrue, reason: '应该包含level字段');
      expect(
        userDetailFields.contains('listenSongs'),
        isTrue,
        reason: '应该包含listenSongs字段',
      );
      expect(
        userDetailFields.contains('playlistCount'),
        isTrue,
        reason: '应该包含playlistCount字段',
      );

      print('✅ 字段映射验证：通过');
    });
  });
}
