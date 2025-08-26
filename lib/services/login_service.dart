
import 'dart:async';

import 'api_manager.dart';
import '../utils/global_config.dart';
import '../utils/app_logger.dart';

/// 登录服务类
/// 使用全局API管理器进行网易云音乐登录
class LoginService {
  static final LoginService _instance = LoginService._internal();
  factory LoginService() => _instance;
  LoginService._internal();

  /// 获取全局配置实例（确保使用已初始化的单例）
  GlobalConfig get _globalConfig => GlobalConfig();

  /// 获取二维码登录key
  Future<String?> getQrKey() async {
    try {
      AppLogger.api('正在获取二维码登录key...');
      // 使用timestamp参数来绕过缓存，确保每次都获取新的key
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      AppLogger.api('使用timestamp: $timestamp');
      
      final result = await ApiManager().api.loginQrKey(timestamp: timestamp);
      
      AppLogger.debug('完整响应: $result');
      
      // Dart API 返回格式: {'status': 200, 'body': {'data': {'code': 200, 'unikey': '...'}, 'code': 200}, 'cookie': ...}
      if (result['status'] == 200 && result['body'] != null && result['body']['code'] == 200) {
        final data = result['body']['data'];
        if (data != null && data['unikey'] != null) {
          AppLogger.api('二维码key获取成功: ${data['unikey']}');
          return data['unikey'];
        }
      }
      
      AppLogger.warning('二维码key获取失败: 响应格式不正确');
      AppLogger.debug('完整响应: $result');
      return null;
    } catch (e) {
      AppLogger.error('二维码key获取异常', e);
      return null;
    }
  }

  /// 创建二维码登录URL
  /// 
  /// [key] 二维码key
  /// 返回二维码URL，失败返回null
  Future<String?> createQrImg(String key) async {
    try {
      AppLogger.api('正在创建二维码图片，key: $key');
      // 使用timestamp参数来绕过缓存，确保每次都生成新的二维码
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      AppLogger.api('使用timestamp: $timestamp');
      
      final result = await ApiManager().api.loginQrCreate(key: key, qrimg: "true", timestamp: timestamp);
      
      AppLogger.debug('完整响应: $result');
      
      // Dart API 返回格式: {'code': 200, 'status': 200, 'body': {'code': 200, 'data': {'qrurl': ..., 'qrimg': ...}}}
      if (result['status'] == 200 && result['body'] != null && result['body']['code'] == 200) {
        final data = result['body']['data'];
        if (data != null && data['qrimg'] != null) {
          AppLogger.api('二维码图片创建成功');
          return data['qrimg'];
        }
      }
      
      AppLogger.warning('二维码图片创建失败: 响应格式不正确');
      AppLogger.debug('完整响应: $result');
      return null;
    } catch (e) {
      AppLogger.error('二维码图片创建异常', e);
      return null;
    }
  }

  /// 检查二维码扫描状态
  /// 
  /// [key] 二维码key
  /// 返回状态码：
  /// - 800: 二维码过期
  /// - 801: 等待扫描
  /// - 802: 待确认
  /// - 803: 登录成功
  Future<Map<String, dynamic>?> checkQrStatus(String key) async {
    try {
      // 每次都添加新的timestamp确保获取最新状态
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final result = await ApiManager().api.loginQrCheck(key: key, timestamp: timestamp);
      
      // Dart API 返回格式: {'status': 200, 'body': {'code': ..., 'cookie': ..., ...}, 'cookie': [...]}
      if (result['status'] == 200 && result['body'] != null) {
        final body = result['body'];
        final code = body['code'];
        
        // 记录状态检查结果
        String statusMessage;
        switch (code) {
          case 800:
            statusMessage = '二维码已过期';
            break;
          case 801:
            statusMessage = '等待扫描';
            break;
          case 802:
            statusMessage = '待确认';
            break;
          case 803:
            statusMessage = '登录成功';
            // 登录成功，保存 cookie
            await _saveCookieOnLoginSuccess(body);
            // 添加调试信息
            AppLogger.debug('登录成功返回的body: $body');
            AppLogger.debug('登录成功返回的完整result: $result');
            break;
          default:
            statusMessage = '未知状态码: $code';
        }
        AppLogger.api('二维码状态检查: $statusMessage (code: $code)');
        
        return body;
      }
      
      AppLogger.warning('二维码状态检查失败: 响应格式不正确');
      return null;
    } catch (e) {
      AppLogger.error('二维码状态检查异常', e);
      return null;
    }
  }

  /// 检查登录状态
  /// 
  /// 检查用户是否已登录
  Future<Map<String, dynamic>?> checkLoginStatus() async {
    try {
      AppLogger.api('正在检查登录状态...');
      final result = await ApiManager().api.loginStatus();
      AppLogger.api('登录状态检查完成');
      return result;
    } catch (e) {
      AppLogger.error('登录状态检查异常', e);
      return null;
    }
  }

  /// 登出
  Future<bool> logout() async {
    try {
      AppLogger.api('正在执行登出...');
      final result = await ApiManager().api.logout();
      final success = result['code'] == 200;
      
      // 如果登出成功，清除本地保存的登录信息
      if (success) {
        AppLogger.api('登出成功，清除本地登录信息');
        await clearSavedLoginInfo();
      } else {
        AppLogger.warning('登出失败，响应码: ${result['code']}');
      }
      
      return success;
    } catch (e) {
      AppLogger.error('登出异常', e);
      return false;
    }
  }

  /// 登录成功时保存 cookie
  Future<void> _saveCookieOnLoginSuccess(Map<String, dynamic> loginResult) async {
    try {
      AppLogger.config('开始保存登录信息...');
      AppLogger.config('GlobalConfig状态: ${_globalConfig.isInitialized ? "已初始化" : "未初始化"}');
      
      // 如果未初始化，进行初始化
      if (!_globalConfig.isInitialized) {
        AppLogger.config('GlobalConfig未初始化，正在初始化...');
        await _globalConfig.initialize();
        AppLogger.config('GlobalConfig初始化完成');
      }
      
      // 从登录结果中提取 cookie 信息
      final cookieString = loginResult['cookie'] as String?;
      if (cookieString != null && cookieString.isNotEmpty) {
        // 保存 cookie 字符串
        await _globalConfig.setUserCookie(cookieString);
        await _globalConfig.setLoggedIn(true);
        AppLogger.config('用户Cookie已保存');
        
        // 立即获取用户信息（智能选择API）
        AppLogger.config('正在获取用户信息...');
        final userInfo = await getSmartUserInfo();
        if (userInfo != null) {
          AppLogger.config('用户信息获取成功');
        } else {
          AppLogger.warning('用户信息获取失败');
        }
        
        AppLogger.config('登录信息保存完成');
      } else {
        AppLogger.warning('警告：登录成功但没有获取到 cookie');
      }
    } catch (e) {
      AppLogger.error('保存登录信息失败', e);
    }
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    try {
      return _globalConfig.isLoggedIn();
    } catch (e) {
      AppLogger.error('检查登录状态失败', e);
      return false;
    }
  }

  /// 获取保存的登录 cookie
  Future<String?> getSavedCookie() async {
    try {
      final cookie = _globalConfig.getUserCookie();
      if (cookie != null) {
        AppLogger.config('获取到保存的Cookie');
      } else {
        AppLogger.config('没有保存的Cookie');
      }
      return cookie;
    } catch (e) {
      AppLogger.error('获取保存的Cookie失败', e);
      return null;
    }
  }

  /// 清除保存的登录信息
  Future<void> clearSavedLoginInfo() async {
    try {
      AppLogger.config('开始清除登录信息...');
      await _globalConfig.setUserCookie('');
      await _globalConfig.clearUserData();
      AppLogger.config('登录信息清除完成');
    } catch (e) {
      AppLogger.error('清除登录信息失败', e);
    }
  }

  /// 获取用户账户信息（用于获取uid）
  Future<Map<String, dynamic>?> getUserAccount() async {
    try {
      AppLogger.api('正在获取用户账户信息...');
      final cookie = await getSavedCookie();
      if (cookie == null || cookie.isEmpty) {
        AppLogger.warning('没有找到保存的Cookie，无法获取用户账户信息');
        return null;
      }

      final result = await ApiManager().api.userAccount(cookie: cookie);
      AppLogger.api('用户账户信息获取完成');
      
      if (result['status'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>;
        if (body['code'] == 200) {
          // 保存用户账户信息到本地配置
          await _saveUserAccount(body);
          return body;
        }
      }
      
      AppLogger.warning('用户账户信息获取失败: 响应格式不正确');
      return null;
    } catch (e) {
      AppLogger.error('用户账户信息获取异常', e);
      return null;
    }
  }

  /// 获取用户详情（用于获取完整用户信息）
  Future<Map<String, dynamic>?> getUserDetail({String? uid}) async {
    try {
      final targetUid = uid ?? _getUserIdFromSavedInfo();
      if (targetUid == null) {
        AppLogger.warning('无法获取用户详情：uid未知');
        return null;
      }

      AppLogger.api('正在获取用户详情，uid: $targetUid');
      final cookie = await getSavedCookie();
      
      final result = await ApiManager().api.userDetail(
        uid: targetUid.toString(), 
        cookie: cookie ?? '',
      );
      AppLogger.api('用户详情获取完成');
      
      if (result['status'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>;
        if (body['code'] == 200) {
          // 保存用户详情到本地配置
          await _saveUserDetail(body);
          return body;
        }
      }
      
      AppLogger.warning('用户详情获取失败: 响应格式不正确');
      return null;
    } catch (e) {
      AppLogger.error('用户详情获取异常', e);
      return null;
    }
  }

  /// 智能获取用户信息
  /// 如果uid已知，使用user/detail接口
  /// 如果uid未知，先使用user/account获取uid，再使用user/detail
  Future<Map<String, dynamic>?> getSmartUserInfo() async {
    try {
      final savedUid = _getUserIdFromSavedInfo();
      
      if (savedUid != null) {
        // uid已知，直接使用user/detail接口
        AppLogger.api('uid已知($savedUid)，使用user/detail接口');
        return await getUserDetail(uid: savedUid.toString());
      } else {
        // uid未知，先使用user/account获取uid
        AppLogger.api('uid未知，先使用user/account获取uid');
        final accountResult = await getUserAccount();
        
        if (accountResult != null) {
          // 从account结果中提取uid
          final account = accountResult['account'] as Map<String, dynamic>?;
          final uid = account?['id'];
          
          if (uid != null) {
            AppLogger.api('从user/account获取到uid: $uid，现在获取用户详情');
            return await getUserDetail(uid: uid.toString());
          }
        }
        
        AppLogger.warning('无法获取用户信息：未能获取到uid');
        return null;
      }
    } catch (e) {
      AppLogger.error('智能获取用户信息失败', e);
      return null;
    }
  }

  /// 从保存的信息中获取用户ID
  int? _getUserIdFromSavedInfo() {
    try {
      final userInfo = _globalConfig.getUserInfo();
      return userInfo?['userId'] as int?;
    } catch (e) {
      return null;
    }
  }

  /// 保存用户账户信息到本地配置
  Future<void> _saveUserAccount(Map<String, dynamic> userAccount) async {
    try {
      AppLogger.config('开始保存用户账户信息...');
      
      // 提取主要用户信息
      final account = userAccount['account'] as Map<String, dynamic>?;
      final profile = userAccount['profile'] as Map<String, dynamic>?;
      
      if (account != null && profile != null) {
        final userInfo = {
          'userId': account['id'],
          'userName': account['userName'],
          'nickname': profile['nickname'],
          'avatarUrl': profile['avatarUrl'],
          'backgroundUrl': profile['backgroundUrl'] ?? '',
          'signature': profile['signature'] ?? '',
          'userType': profile['userType'] ?? 0,
          'accountStatus': account['status'],
          'vipType': account['vipType'] ?? 0,
          'createTime': account['createTime'],
          'gender': profile['gender'] ?? 0,
          'birthday': profile['birthday'],
          'province': profile['province'] ?? 0,
          'city': profile['city'] ?? 0,
          'followed': profile['followed'] ?? false,
          'followeds': profile['followeds'] ?? 0,
          'follows': profile['follows'] ?? 0,
          'updateTime': DateTime.now().millisecondsSinceEpoch,
        };
        
        // 将用户信息转换为JSON字符串存储
        await _globalConfig.setUserInfo(userInfo);
        AppLogger.config('用户账户信息保存成功');
      }
    } catch (e) {
      AppLogger.error('保存用户账户信息失败', e);
    }
  }

  /// 保存用户详情到本地配置
  Future<void> _saveUserDetail(Map<String, dynamic> userDetail) async {
    try {
      AppLogger.config('开始保存用户详情信息...');
      
      // 提取用户详情信息
      final profile = userDetail['profile'] as Map<String, dynamic>?;
      final level = userDetail['level'];
      final listenSongs = userDetail['listenSongs'];
      
      if (profile != null) {
        final userInfo = {
          'userId': profile['userId'],
          'nickname': profile['nickname'],
          'avatarUrl': profile['avatarUrl'],
          'signature': profile['signature'] ?? '',
          'userType': profile['userType'] ?? 0,
          'vipType': profile['vipType'] ?? 0,
          'gender': profile['gender'] ?? 0,
          'birthday': profile['birthday'],
          'province': profile['province'] ?? 0,
          'city': profile['city'] ?? 0,
          'followed': profile['followed'] ?? false,
          'followeds': profile['followeds'] ?? 0,
          'follows': profile['follows'] ?? 0,
          'level': level ?? 0,
          'listenSongs': listenSongs ?? 0,
          'createTime': profile['createTime'] ?? -1,
          'description': profile['description'] ?? '',
          'detailDescription': profile['detailDescription'] ?? '',
          'eventCount': profile['eventCount'] ?? 0,
          'playlistCount': profile['playlistCount'] ?? 0,
          'playlistBeSubscribedCount': profile['playlistBeSubscribedCount'] ?? 0,
          'djStatus': profile['djStatus'] ?? 0,
          'mutual': profile['mutual'] ?? false,
          'accountStatus': profile['accountStatus'] ?? 0,
          'authStatus': profile['authStatus'] ?? 0,
          'authority': profile['authority'] ?? 0,
          'backgroundUrl': profile['backgroundUrl'] ?? '',
          'defaultAvatar': profile['defaultAvatar'] ?? false,
          'updateTime': DateTime.now().millisecondsSinceEpoch,
        };
        
        // 将用户信息转换为JSON字符串存储
        await _globalConfig.setUserInfo(userInfo);
        AppLogger.config('用户详情信息保存成功');
      }
    } catch (e) {
      AppLogger.error('保存用户详情信息失败', e);
    }
  }

  /// 获取保存的用户账户信息
  Map<String, dynamic>? getSavedUserAccount() {
    try {
      return _globalConfig.getUserInfo();
    } catch (e) {
      AppLogger.error('获取保存的用户账户信息失败', e);
      return null;
    }
  }
}
