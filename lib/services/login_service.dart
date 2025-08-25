import 'dart:async';

import 'api_manager.dart';
import '../utils/global_config.dart';

/// 登录服务类
/// 使用全局API管理器进行网易云音乐登录
class LoginService {
  static final LoginService _instance = LoginService._internal();
  factory LoginService() => _instance;
  LoginService._internal();

  /// 获取二维码登录key
  Future<String?> getQrKey() async {
    try {
      print('[API] 正在获取二维码登录key...');
      final result = await ApiManager().call('loginQrKey', {});
      
      // Dart API 返回格式: {'status': 200, 'body': {'data': {'code': 200, 'unikey': '...'}, 'code': 200}, 'cookie': ...}
      if (result['status'] == 200 && result['body'] != null && result['body']['code'] == 200) {
        final data = result['body']['data'];
        if (data != null && data['unikey'] != null) {
          print('[API] 二维码key获取成功: ${data['unikey']}');
          return data['unikey'];
        }
      }
      
      print('[API] 二维码key获取失败: 响应格式不正确');
      return null;
    } catch (e) {
      print('[API] 二维码key获取异常: $e');
      return null;
    }
  }

  /// 创建二维码登录URL
  /// 
  /// [key] 二维码key
  /// 返回二维码URL，失败返回null
  Future<String?> createQrImg(String key) async {
    try {
      print('[API] 正在创建二维码图片，key: $key');
      final result = await ApiManager().call('loginQrCreate', {
        'key': key,
        'qrimg': true,
      });
      
      // Dart API 返回格式: {'code': 200, 'status': 200, 'body': {'code': 200, 'data': {'qrurl': ..., 'qrimg': ...}}}
      if (result['status'] == 200 && result['body'] != null && result['body']['code'] == 200) {
        final data = result['body']['data'];
        if (data != null && data['qrimg'] != null) {
          print('[API] 二维码图片创建成功');
          return data['qrimg'];
        }
      }
      
      print('[API] 二维码图片创建失败: 响应格式不正确');
      return null;
    } catch (e) {
      print('[API] 二维码图片创建异常: $e');
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
      final params = {
        'key': key,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      final result = await ApiManager().call('loginQrCheck', params);
      
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
            break;
          default:
            statusMessage = '未知状态码: $code';
        }
        print('[API] 二维码状态检查: $statusMessage (code: $code)');
        
        return body;
      }
      
      print('[API] 二维码状态检查失败: 响应格式不正确');
      return null;
    } catch (e) {
      print('[API] 二维码状态检查异常: $e');
      return null;
    }
  }

  /// 检查登录状态
  /// 
  /// 检查用户是否已登录
  Future<Map<String, dynamic>?> checkLoginStatus() async {
    try {
      print('[API] 正在检查登录状态...');
      final result = await ApiManager().call('loginStatus', {});
      print('[API] 登录状态检查完成');
      return result;
    } catch (e) {
      print('[API] 登录状态检查异常: $e');
      return null;
    }
  }

  /// 登出
  Future<bool> logout() async {
    try {
      print('[API] 正在执行登出...');
      final result = await ApiManager().call('logout', {});
      final success = result['code'] == 200;
      
      // 如果登出成功，清除本地保存的登录信息
      if (success) {
        print('[API] 登出成功，清除本地登录信息');
        await clearSavedLoginInfo();
      } else {
        print('[API] 登出失败，响应码: ${result['code']}');
      }
      
      return success;
    } catch (e) {
      print('[API] 登出异常: $e');
      return false;
    }
  }

  /// 登录成功时保存 cookie
  Future<void> _saveCookieOnLoginSuccess(Map<String, dynamic> loginResult) async {
    try {
      print('[CONFIG] 开始保存登录信息...');
      
      // 从登录结果中提取 cookie 信息
      final cookieString = loginResult['cookie'] as String?;
      if (cookieString != null && cookieString.isNotEmpty) {
        // 保存 cookie 字符串
        await GlobalConfig().setUserCookie(cookieString);
        print('[CONFIG] 用户Cookie已保存');
        
        print('[CONFIG] 登录信息保存完成');
      } else {
        print('[CONFIG] 警告：登录成功但没有获取到 cookie');
      }
    } catch (e) {
      print('[CONFIG] 保存登录信息失败: $e');
    }
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    try {
      return await GlobalConfig().isLoggedIn();
    } catch (e) {
      print('[CONFIG] 检查登录状态失败: $e');
      return false;
    }
  }

  /// 获取保存的登录 cookie
  Future<String?> getSavedCookie() async {
    try {
      final cookie = await GlobalConfig().getUserCookie();
      if (cookie != null) {
        print('[CONFIG] 获取到保存的Cookie');
      } else {
        print('[CONFIG] 没有保存的Cookie');
      }
      return cookie;
    } catch (e) {
      print('[CONFIG] 获取保存的Cookie失败: $e');
      return null;
    }
  }

  /// 清除保存的登录信息
  Future<void> clearSavedLoginInfo() async {
    try {
      print('[CONFIG] 开始清除登录信息...');
      await GlobalConfig().setUserCookie('');
      print('[CONFIG] 登录信息清除完成');
    } catch (e) {
      print('[CONFIG] 清除登录信息失败: $e');
    }
  }
}
