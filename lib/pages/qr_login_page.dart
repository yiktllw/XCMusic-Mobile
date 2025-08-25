import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    });

    try {
      // 获取二维码key
      final qrKey = await _loginService.getQrKey();
      if (qrKey == null) {
        setState(() {
          _statusMessage = '获取二维码失败，请重试';
          _isLoading = false;
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
      });

      // 开始轮询登录状态
      _startPolling();
    } catch (e) {
      setState(() {
        _statusMessage = '网络错误: $e';
        _isLoading = false;
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
            });
            break;
          case 802:
            // 待确认
            setState(() {
              _statusMessage = '请在手机上确认登录';
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
            });
            if (mounted) {
              _notificationService.showSuccess('登录成功！', context);
              Navigator.of(context).pop(result);
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
    _pollTimer?.cancel();
    _initQrCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二维码登录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
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
              
              // 状态信息
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
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
