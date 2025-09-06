import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/smart_detection_service.dart';
import '../utils/app_logger.dart';

/// 传感器权限设置页面
class SensorPermissionPage extends StatefulWidget {
  const SensorPermissionPage({super.key});

  @override
  State<SensorPermissionPage> createState() => _SensorPermissionPageState();
}

class _SensorPermissionPageState extends State<SensorPermissionPage> {
  bool _isChecking = false;
  bool _hasPermission = false;
  bool _sensorsAvailable = false;
  String _permissionStatus = '检查中...';
  String _sensorStatus = '检查中...';
  String _detailedStatus = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final smartDetection = SmartDetectionService();
      await smartDetection.initialize();
      
      setState(() {
        _hasPermission = smartDetection.hasPermission;
        _sensorsAvailable = smartDetection.sensorsAvailable;
        _permissionStatus = _hasPermission ? '已授权' : '未授权';
        _sensorStatus = _sensorsAvailable ? '可用' : '不可用';
        _detailedStatus = smartDetection.statusInfo;
      });
      
      AppLogger.info('权限检查完成: 权限=$_hasPermission, 传感器=$_sensorsAvailable, 详情=$_detailedStatus');
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _sensorsAvailable = false;
        _permissionStatus = '检查失败';
        _sensorStatus = '检查失败';
        _detailedStatus = '检查过程中发生错误';
      });
      AppLogger.error('权限检查失败', e);
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isChecking = true;
    });

    try {
      // 首先尝试直接访问传感器
      bool canAccessSensors = false;
      try {
        final completer = Completer<bool>();
        late StreamSubscription<AccelerometerEvent> testSubscription;
        
        Timer(const Duration(seconds: 1), () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        });
        
        testSubscription = accelerometerEventStream().listen(
          (event) {
            if (!completer.isCompleted) {
              canAccessSensors = true;
              completer.complete(true);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        );
        
        canAccessSensors = await completer.future;
        testSubscription.cancel();
        
        if (canAccessSensors) {
          setState(() {
            _hasPermission = true;
            _sensorsAvailable = true;
            _permissionStatus = '已授权';
            _sensorStatus = '可用';
            _detailedStatus = '传感器可正常访问';
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('传感器可正常使用'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      } catch (e) {
        AppLogger.warning('直接传感器测试失败', e);
      }
      
      // 如果直接访问失败，尝试权限请求
      try {
        final status = await Permission.sensors.request();
        
        if (status.isGranted) {
          setState(() {
            _hasPermission = true;
            _permissionStatus = '已授权';
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('传感器权限已授权'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          // 重新检查传感器可用性
          await _checkPermissions();
        } else if (status.isPermanentlyDenied) {
          setState(() {
            _hasPermission = false;
            _permissionStatus = '永久拒绝';
            _detailedStatus = '需要手动在系统设置中开启权限';
          });
          
          _showOpenSettingsDialog();
        } else {
          setState(() {
            _hasPermission = false;
            _permissionStatus = '已拒绝';
            _detailedStatus = '权限被拒绝，但大多数设备的传感器不需要特殊权限';
          });
          
          // 显示手动指导对话框
          _showManualGuideDialog();
        }
      } catch (e) {
        setState(() {
          _hasPermission = false;
          _permissionStatus = '请求失败';
          _detailedStatus = '权限API不可用，这在某些设备上是正常的';
        });
        
        // 显示手动指导对话框
        _showManualGuideDialog();
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _permissionStatus = '检查失败';
        _detailedStatus = '传感器检查过程中发生错误';
      });
      AppLogger.error('权限请求失败', e);
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('权限设置'),
        content: const Text('传感器权限已被永久拒绝，请前往系统设置手动开启。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  void _showManualGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('传感器访问指导'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('大多数Android设备的传感器不需要特殊权限。如果智能检测功能无法使用，请尝试以下步骤：'),
              const SizedBox(height: 12),
              const Text('1. 重启应用'),
              const Text('2. 检查设备是否支持传感器'),
              const Text('3. 确保应用有足够的权限'),
              const Text('4. 在某些设备上，可能需要在"隐私保护"或"应用权限"中手动开启'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '注意：即使显示权限不足，传感器功能在大多数设备上仍可正常工作。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('了解'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  void _forceEnableSensors() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('强制启用传感器'),
        content: const Text(
          '这将忽略权限检查，强制启用智能检测功能。\n\n'
          '在大多数设备上，即使权限检查失败，传感器仍然可以正常工作。\n\n'
          '确定要继续吗？'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              setState(() {
                _hasPermission = true;
                _sensorsAvailable = true;
                _permissionStatus = '强制启用';
                _sensorStatus = '强制启用';
                _detailedStatus = '已强制启用，如果不工作请联系开发者';
              });
              
              // 尝试强制初始化智能检测服务
              try {
                final smartDetection = SmartDetectionService();
                // 绕过权限检查，直接测试传感器
                final testResult = await smartDetection.testSensorsAvailability();
                
                // 强制更新状态
                smartDetection.forceUpdatePermissionStatus(true, testResult);
                
                setState(() {
                  _sensorsAvailable = testResult;
                  _sensorStatus = testResult ? '可用' : '不可用';
                  _detailedStatus = testResult 
                    ? '强制启用成功，传感器正常工作' 
                    : '强制启用，但传感器可能不工作';
                });
                
                final message = testResult ? '强制启用成功！' : '强制启用，但传感器可能不工作';
                final color = testResult ? Colors.green : Colors.orange;
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: color,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _detailedStatus = '强制启用失败: $e';
                });
                AppLogger.error('强制启用传感器失败', e);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('传感器权限'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 权限状态卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_hasPermission && _sensorsAvailable)
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    (_hasPermission && _sensorsAvailable) ? Icons.check_circle : Icons.error,
                    size: 48,
                    color: (_hasPermission && _sensorsAvailable)
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '智能检测状态',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: (_hasPermission && _sensorsAvailable)
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detailedStatus.isNotEmpty ? _detailedStatus : _permissionStatus,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: (_hasPermission && _sensorsAvailable)
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasPermission || _sensorsAvailable) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusChip(
                          context,
                          '权限',
                          _permissionStatus,
                          _hasPermission,
                        ),
                        _buildStatusChip(
                          context,
                          '传感器',
                          _sensorStatus,
                          _sensorsAvailable,
                        ),
                      ],
                    ),
                  ],
                  if (!_hasPermission && !_isChecking) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _requestPermissions,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            child: const Text('重新检测'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _forceEnableSensors,
                            child: const Text('强制启用'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!_sensorsAvailable && !_isChecking) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _checkPermissions,
                      child: const Text('重新检测'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 功能说明
            Text(
              '智能关闭功能说明',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem(
                      context,
                      Icons.sensors,
                      '加速度传感器监听',
                      '实时监测设备运动状态，判断用户活动程度',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      Icons.psychology,
                      '智能睡眠检测',
                      '通过运动数据分析判断用户是否进入睡眠状态',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      Icons.timer_sharp,
                      '动态时间调整',
                      '根据检测结果自动缩短或延长定时关闭时间',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      context,
                      Icons.schedule,
                      '时间段智能',
                      '结合当前时间段优化检测算法和调整策略',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 权限说明
            Text(
              '权限说明',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '为什么需要传感器权限？',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 访问加速度传感器和陀螺仪数据',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '• 监测设备运动状态变化',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '• 实现智能睡眠检测算法',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '常见问题解答：',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Q: 为什么没有看到权限请求对话框？',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'A: 大多数Android设备的传感器不需要特殊权限，系统会自动授权。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Q: 显示"权限不足"怎么办？',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'A: 可以尝试"强制启用"功能，传感器在大多数情况下仍能正常工作。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '我们只在本地处理传感器数据，不会上传或共享任何个人信息',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String label, String status, bool isOk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
          : Theme.of(context).colorScheme.errorContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOk 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
            : Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isOk 
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOk 
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
