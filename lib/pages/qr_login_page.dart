import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import '../services/login_service.dart';
import '../services/notification_service.dart';

/// 二维码登录页面
class QrLoginPage extends StatefulWidget {
  const QrLoginPage({super.key});

  @override
  State<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends State<QrLoginPage> {
  final LoginService _loginService = LoginService();
  final NotificationService _notificationService = NotificationService();

  String? _qrKey;
  String? _qrUrl;
  String _statusMessage = '正在生成二维码...';
  bool _isLoading = true;
  Timer? _pollTimer;
  int _qrStatus = 0; // 0: 生成中, 801: 等待扫描, 802: 待确认, 803: 成功, 800: 过期

  @override
  void initState() {
    super.initState();
    _initQrCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 初始化二维码
  Future<void> _initQrCode() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在生成二维码...';
      _qrStatus = 0; // 设置为生成中状态
    });

    try {
      // 获取二维码key
      final qrKey = await _loginService.getQrKey();
      if (qrKey == null) {
        setState(() {
          _statusMessage = '获取二维码失败，请重试';
          _isLoading = false;
          _qrStatus = -1; // 错误状态
        });
        if (mounted) {
          _notificationService.showError('获取二维码key失败，请检查网络连接', context);
        }
        return;
      }

      // 创建二维码URL
      final qrUrl = await _loginService.createQrImg(qrKey);
      if (qrUrl == null) {
        setState(() {
          _statusMessage = '生成二维码失败，请重试';
          _isLoading = false;
          _qrStatus = -1; // 错误状态
        });
        if (mounted) {
          _notificationService.showError('生成二维码失败，请重试', context);
        }
        return;
      }

      setState(() {
        _qrKey = qrKey;
        _qrUrl = qrUrl;
        _statusMessage = '请使用网易云音乐APP扫描二维码';
        _isLoading = false;
        _qrStatus = 801; // 等待扫描状态
      });

      // 开始轮询登录状态
      _startPolling();
    } catch (e) {
      setState(() {
        _statusMessage = '网络错误: $e';
        _isLoading = false;
        _qrStatus = -1; // 错误状态
      });
      if (mounted) {
        _notificationService.showError('初始化失败: $e', context);
      }
    }
  }

  /// 开始轮询登录状态
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_qrKey == null) return;

      try {
        final result = await _loginService.checkQrStatus(_qrKey!);
        if (result == null) return;

        final code = result['code'];
        switch (code) {
          case 800:
            // 二维码过期
            _pollTimer?.cancel();
            setState(() {
              _statusMessage = '二维码已过期，正在重新生成...';
              _qrStatus = 800;
            });
            if (mounted) {
              _notificationService.showError('二维码已过期，正在重新生成', context);
            }
            _initQrCode();
            break;
          case 801:
            // 等待扫描
            setState(() {
              _statusMessage = '请使用网易云音乐APP扫描二维码';
              _qrStatus = 801;
            });
            break;
          case 802:
            // 待确认
            setState(() {
              _statusMessage = '请在手机上确认登录';
              _qrStatus = 802;
            });
            if (mounted) {
              _notificationService.showWarning('请在手机上确认登录', context);
            }
            break;
          case 803:
            // 登录成功
            _pollTimer?.cancel();
            setState(() {
              _statusMessage = '登录成功！';
              _qrStatus = 803;
            });
            if (mounted) {
              _notificationService.showSuccess('登录成功！', context);
              // 添加调试信息
              AppLogger.info('[QR_LOGIN] 登录成功，result: $result');
              // 构造返回对象，确保包含cookie信息
              final loginSuccessResult = {
                'success': true,
                'cookie': result['cookie'], // 从result中提取cookie
                'data': result, // 保留原始数据
              };
              AppLogger.info('[QR_LOGIN] 构造的返回对象: $loginSuccessResult');
              Navigator.of(context).pop(loginSuccessResult);
            }
            break;
        }
      } catch (e) {
        setState(() {
          _statusMessage = '检查登录状态失败: $e';
        });
      }
    });
  }

  /// 刷新二维码
  void _refreshQrCode() {
    AppLogger.info('[QR] 用户点击刷新按钮');
    _pollTimer?.cancel();
    setState(() {
      _qrKey = null;
      _qrUrl = null;
    });
    _initQrCode();
  }

  /// 根据状态获取对应的颜色
  Color _getStatusColor() {
    switch (_qrStatus) {
      case -1: // 错误状态
        return Colors.red;
      case 0: // 生成中
        return Colors.orange;
      case 800: // 过期
        return Colors.red;
      case 801: // 等待扫描
        return Colors.blue;
      case 802: // 待确认
        return Colors.amber;
      case 803: // 成功
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// 根据状态获取对应的图标
  IconData _getStatusIcon() {
    switch (_qrStatus) {
      case -1: // 错误状态
        return Icons.error_outline;
      case 0: // 生成中
        return Icons.hourglass_empty;
      case 800: // 过期
        return Icons.error_outline;
      case 801: // 等待扫描
        return Icons.qr_code_scanner;
      case 802: // 待确认
        return Icons.touch_app;
      case 803: // 成功
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二维码登录'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshQrCode,
            tooltip: '刷新二维码',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                '网易云音乐登录',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // 二维码区域
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _qrUrl != null
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: QrImageView(
                          data: _qrUrl!,
                          version: QrVersions.auto,
                          size: 230,
                          backgroundColor: Colors.white,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // 状态信息区域
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _refreshQrCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 使用说明
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '登录步骤：',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('1. 打开网易云音乐APP'),
                      Text('2. 点击左上角头像'),
                      Text('3. 点击"扫一扫"'),
                      Text('4. 扫描上方二维码'),
                      Text('5. 在手机上确认登录'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
