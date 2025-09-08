import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_logger.dart';

/// 智能检测服务
/// 通过多种传感器和系统状态检测用户活动和睡眠状态
class SmartDetectionService extends ChangeNotifier {
  static final SmartDetectionService _instance =
      SmartDetectionService._internal();
  factory SmartDetectionService() => _instance;
  SmartDetectionService._internal();

  // 加速度传感器相关
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<AccelerometerEvent> _accelerometerBuffer = [];
  static const int _bufferSize = 300; // 5分钟的数据（每秒1个数据点）

  // 陀螺仪传感器相关
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  final List<GyroscopeEvent> _gyroscopeBuffer = [];

  // 状态检测
  bool _isMonitoring = false;
  bool _hasPermission = false;
  bool _sensorsAvailable = false;
  String _initializationError = '';

  // 睡眠检测参数
  static const double _sleepThreshold = 0.5; // 静止状态阈值
  static const int _checkIntervalSeconds = 30; // 每30秒检查一次
  static const int _actionTriggerIntervalMinutes = 5; // 每5分钟最多触发一次调整

  Timer? _analysisTimer;
  DateTime? _lastActionTime; // 上次触发调整的时间

  // 回调函数
  Function(SleepDetectionResult)? _onSleepDetected;

  /// 初始化服务
  Future<bool> initialize() async {
    try {
      AppLogger.info('开始初始化智能检测服务...');

      // 首先检查权限
      _hasPermission = await _requestPermissions();
      AppLogger.info('权限检查结果: $_hasPermission');

      // 然后测试传感器可用性
      _sensorsAvailable = await _testSensorsAvailability();
      AppLogger.info('传感器可用性检查结果: $_sensorsAvailable');

      final isInitialized = _hasPermission && _sensorsAvailable;

      if (isInitialized) {
        AppLogger.info('智能检测服务初始化成功');
        _initializationError = '';
      } else {
        final reasons = <String>[];
        if (!_hasPermission) reasons.add('权限不足');
        if (!_sensorsAvailable) reasons.add('传感器不可用');
        _initializationError = '初始化失败: ${reasons.join(', ')}';
        AppLogger.warning('智能检测服务初始化失败: $_initializationError');
      }

      // 通知状态变化
      notifyListeners();

      return isInitialized;
    } catch (e) {
      _initializationError = '初始化异常: $e';
      AppLogger.error('智能检测服务初始化失败', e);
      notifyListeners();
      return false;
    }
  }

  /// 请求必要权限
  Future<bool> _requestPermissions() async {
    try {
      AppLogger.info('检查传感器权限...');

      // 对于传感器，大多数Android设备不需要运行时权限
      // 我们首先尝试直接测试传感器可用性
      try {
        // 简单测试：尝试获取一次传感器数据
        bool canAccessSensors = false;
        final completer = Completer<bool>();

        late StreamSubscription<AccelerometerEvent> testSubscription;
        Timer(const Duration(milliseconds: 500), () {
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
            AppLogger.info('传感器访问测试失败: $error');
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        );

        canAccessSensors = await completer.future;
        testSubscription.cancel();

        if (canAccessSensors) {
          AppLogger.info('传感器可直接访问，无需特殊权限');
          return true;
        }

        AppLogger.info('传感器不能直接访问，尝试权限请求...');
      } catch (e) {
        AppLogger.info('传感器访问测试异常: $e');
      }

      // 如果直接访问失败，尝试权限请求
      try {
        final currentStatus = await Permission.sensors.status;
        AppLogger.info('传感器权限状态: $currentStatus');

        if (currentStatus.isDenied) {
          AppLogger.info('请求传感器权限...');
          final status = await Permission.sensors.request();
          AppLogger.info('权限请求结果: $status');
          return status.isGranted || status.isLimited;
        }

        // 对于其他状态，检查是否已授权
        final isGranted =
            currentStatus.isGranted ||
            currentStatus.isLimited ||
            currentStatus.isRestricted;

        AppLogger.info('最终权限状态: $isGranted');
        return isGranted;
      } catch (e) {
        AppLogger.info('权限API不可用: $e');
        // 如果权限API不可用，但传感器测试也失败了，返回false
        return false;
      }
    } catch (e) {
      AppLogger.error('权限检查异常', e);
      return false;
    }
  }

  /// 测试传感器可用性
  Future<bool> _testSensorsAvailability() async {
    try {
      AppLogger.info('测试传感器可用性...');

      bool accelerometerWorking = false;
      bool gyroscopeWorking = false;

      // 测试加速度传感器
      try {
        final accelerometerCompleter = Completer<bool>();
        late StreamSubscription<AccelerometerEvent> testSubscription;

        Timer(const Duration(seconds: 2), () {
          if (!accelerometerCompleter.isCompleted) {
            accelerometerCompleter.complete(false);
          }
        });

        testSubscription = accelerometerEventStream().listen(
          (event) {
            if (!accelerometerCompleter.isCompleted) {
              accelerometerWorking = true;
              accelerometerCompleter.complete(true);
            }
          },
          onError: (error) {
            AppLogger.warning('加速度传感器测试失败', error);
            if (!accelerometerCompleter.isCompleted) {
              accelerometerCompleter.complete(false);
            }
          },
        );

        accelerometerWorking = await accelerometerCompleter.future;
        testSubscription.cancel();

        AppLogger.info('加速度传感器测试结果: $accelerometerWorking');
      } catch (e) {
        AppLogger.error('加速度传感器测试异常', e);
      }

      // 测试陀螺仪传感器
      try {
        final gyroscopeCompleter = Completer<bool>();
        late StreamSubscription<GyroscopeEvent> testSubscription;

        Timer(const Duration(seconds: 2), () {
          if (!gyroscopeCompleter.isCompleted) {
            gyroscopeCompleter.complete(false);
          }
        });

        testSubscription = gyroscopeEventStream().listen(
          (event) {
            if (!gyroscopeCompleter.isCompleted) {
              gyroscopeWorking = true;
              gyroscopeCompleter.complete(true);
            }
          },
          onError: (error) {
            AppLogger.warning('陀螺仪传感器测试失败', error);
            if (!gyroscopeCompleter.isCompleted) {
              gyroscopeCompleter.complete(false);
            }
          },
        );

        gyroscopeWorking = await gyroscopeCompleter.future;
        testSubscription.cancel();

        AppLogger.info('陀螺仪传感器测试结果: $gyroscopeWorking');
      } catch (e) {
        AppLogger.error('陀螺仪传感器测试异常', e);
      }

      // 至少一个传感器工作就认为可用
      final sensorsAvailable = accelerometerWorking || gyroscopeWorking;
      AppLogger.info(
        '传感器总体可用性: $sensorsAvailable (加速度: $accelerometerWorking, 陀螺仪: $gyroscopeWorking)',
      );

      return sensorsAvailable;
    } catch (e) {
      AppLogger.error('传感器可用性测试失败', e);
      return false;
    }
  }

  /// 开始监听传感器数据
  Future<void> startMonitoring({
    required Function(SleepDetectionResult) onSleepDetected,
  }) async {
    if (!_hasPermission || !_sensorsAvailable) {
      AppLogger.warning(
        '传感器不可用，无法启动智能监听: 权限=$_hasPermission, 传感器=$_sensorsAvailable',
      );
      return;
    }

    if (_isMonitoring) {
      AppLogger.info('智能监听已在运行中');
      return;
    }

    _onSleepDetected = onSleepDetected;
    _isMonitoring = true;

    try {
      // 启动加速度传感器监听
      _accelerometerSubscription = accelerometerEventStream().listen(
        _onAccelerometerEvent,
        onError: (error) {
          AppLogger.error('加速度传感器监听错误', error);
        },
      );

      // 启动陀螺仪监听
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        _onGyroscopeEvent,
        onError: (error) {
          AppLogger.error('陀螺仪传感器监听错误', error);
        },
      );

      // 启动分析定时器
      _analysisTimer = Timer.periodic(
        Duration(seconds: _checkIntervalSeconds),
        _analyzeMotionData,
      );

      AppLogger.info(
        '智能检测监听已启动 - 传感器状态: 权限=$_hasPermission, 可用=$_sensorsAvailable, 详情=$statusInfo',
      );
    } catch (e) {
      AppLogger.error('启动传感器监听失败', e);
      _isMonitoring = false;
    }
  }

  /// 停止监听
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _analysisTimer?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _analysisTimer = null;

    _accelerometerBuffer.clear();
    _gyroscopeBuffer.clear();

    _isMonitoring = false;
    _onSleepDetected = null;
    _lastActionTime = null; // 重置触发时间

    AppLogger.info('智能检测监听已停止');
  }

  /// 处理加速度传感器数据
  void _onAccelerometerEvent(AccelerometerEvent event) {
    _accelerometerBuffer.add(event);

    // 保持缓冲区大小
    if (_accelerometerBuffer.length > _bufferSize) {
      _accelerometerBuffer.removeAt(0);
    }
  }

  /// 处理陀螺仪数据
  void _onGyroscopeEvent(GyroscopeEvent event) {
    _gyroscopeBuffer.add(event);

    // 保持缓冲区大小
    if (_gyroscopeBuffer.length > _bufferSize) {
      _gyroscopeBuffer.removeAt(0);
    }
  }

  /// 分析运动数据
  void _analyzeMotionData(Timer timer) {
    if (_accelerometerBuffer.isEmpty) return;

    try {
      final result = _detectSleepState();

      // 检查是否需要触发调整（需要有推荐动作且满足时间间隔）
      if ((result.isSleeping ||
              result.recommendedAction == RecommendedAction.extendToMinimum) &&
          result.recommendedAction != RecommendedAction.none &&
          _shouldTriggerAction() &&
          _onSleepDetected != null) {
        // 记录触发时间
        _lastActionTime = DateTime.now();
        _onSleepDetected!(result);

        AppLogger.info(
          '触发智能调整: ${result.recommendedAction}, 下次最早触发时间: ${DateTime.now().add(Duration(minutes: _actionTriggerIntervalMinutes))}',
        );
      }

      // 记录检测结果（调试用）
      if (kDebugMode) {
        AppLogger.info('智能检测结果: ${result.toString()}');
      }
    } catch (e) {
      AppLogger.error('分析运动数据时出错', e);
    }
  }

  /// 检查是否应该触发动作（基于时间间隔）
  bool _shouldTriggerAction() {
    if (_lastActionTime == null) {
      return true; // 首次触发
    }

    final now = DateTime.now();
    final timeSinceLastAction = now.difference(_lastActionTime!);
    final shouldTrigger =
        timeSinceLastAction.inMinutes >= _actionTriggerIntervalMinutes;

    if (!shouldTrigger) {
      final remainingMinutes =
          _actionTriggerIntervalMinutes - timeSinceLastAction.inMinutes;
      AppLogger.info('距离上次调整不足5分钟，还需等待 $remainingMinutes 分钟');
    }

    return shouldTrigger;
  }

  /// 检测睡眠状态
  SleepDetectionResult _detectSleepState() {
    if (_accelerometerBuffer.length < 60) {
      // 数据不足，无法判断
      return SleepDetectionResult(
        isSleeping: false,
        confidence: 0.0,
        activityLevel: ActivityLevel.unknown,
        recommendedAction: RecommendedAction.none,
        analysisDetails: '数据收集中...',
      );
    }

    // 计算最近5分钟的运动强度
    final recentData = _accelerometerBuffer.length >= 300
        ? _accelerometerBuffer.sublist(_accelerometerBuffer.length - 300)
        : _accelerometerBuffer;

    // 计算运动强度指标
    final motionIntensity = _calculateMotionIntensity(recentData);
    final motionVariability = _calculateMotionVariability(recentData);
    final stillPeriods = _countStillPeriods(recentData);

    // 时间因素
    final timeWeight = _getTimeWeight();

    // 综合分析
    return _generateSleepAnalysis(
      motionIntensity: motionIntensity,
      motionVariability: motionVariability,
      stillPeriods: stillPeriods,
      timeWeight: timeWeight,
    );
  }

  /// 计算运动强度
  double _calculateMotionIntensity(List<AccelerometerEvent> data) {
    if (data.isEmpty) return 0.0;

    double totalIntensity = 0.0;

    for (final event in data) {
      // 计算总加速度 - 重力加速度
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.8;

      totalIntensity += magnitude.abs();
    }

    return totalIntensity / data.length;
  }

  /// 计算运动变化幅度
  double _calculateMotionVariability(List<AccelerometerEvent> data) {
    if (data.length < 2) return 0.0;

    final intensities = data.map((event) {
      return sqrt(event.x * event.x + event.y * event.y + event.z * event.z) -
          9.8;
    }).toList();

    // 计算标准差
    final mean = intensities.reduce((a, b) => a + b) / intensities.length;
    final variance =
        intensities
            .map((intensity) => pow(intensity - mean, 2))
            .reduce((a, b) => a + b) /
        intensities.length;

    return sqrt(variance);
  }

  /// 计算静止时段数量
  int _countStillPeriods(List<AccelerometerEvent> data) {
    if (data.isEmpty) return 0;

    int stillPeriods = 0;
    int consecutiveStillCount = 0;
    const int stillThresholdCount = 30; // 30秒连续静止算一个时段

    for (final event in data) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.8;

      if (magnitude.abs() < _sleepThreshold) {
        consecutiveStillCount++;
        if (consecutiveStillCount >= stillThresholdCount) {
          stillPeriods++;
          consecutiveStillCount = 0; // 重置计数
        }
      } else {
        consecutiveStillCount = 0;
      }
    }

    return stillPeriods;
  }

  /// 获取时间权重
  double _getTimeWeight() {
    final hour = DateTime.now().hour;

    if ((hour >= 22) || (hour <= 6)) {
      // 夜间时段，睡眠可能性高
      return 1.5;
    } else if (hour >= 12 && hour <= 14) {
      // 午休时段，中等可能性
      return 1.2;
    } else if (hour >= 20 && hour <= 22) {
      // 晚间时段，较高可能性
      return 1.3;
    } else {
      // 其他时段，较低可能性
      return 0.8;
    }
  }

  /// 生成睡眠分析结果
  SleepDetectionResult _generateSleepAnalysis({
    required double motionIntensity,
    required double motionVariability,
    required int stillPeriods,
    required double timeWeight,
  }) {
    // 计算睡眠置信度
    double confidence = 0.0;

    // 运动强度评分 (越低越可能睡眠)
    if (motionIntensity < 0.1) {
      confidence += 30;
    } else if (motionIntensity < 0.3) {
      confidence += 20;
    } else if (motionIntensity < 0.5) {
      confidence += 10;
    }

    // 运动变化评分 (越低越可能睡眠)
    if (motionVariability < 0.1) {
      confidence += 25;
    } else if (motionVariability < 0.3) {
      confidence += 15;
    } else if (motionVariability < 0.5) {
      confidence += 5;
    }

    // 静止时段评分
    confidence += stillPeriods * 10;

    // 时间权重调整
    confidence *= timeWeight;

    // 限制在0-100范围内
    confidence = confidence.clamp(0.0, 100.0);

    // 确定活动等级
    ActivityLevel activityLevel;
    if (motionIntensity < 0.1 && stillPeriods >= 2) {
      activityLevel = ActivityLevel.sleeping;
    } else if (motionIntensity < 0.3) {
      activityLevel = ActivityLevel.resting;
    } else if (motionIntensity < 0.8) {
      activityLevel = ActivityLevel.light;
    } else {
      activityLevel = ActivityLevel.active;
    }

    // 确定推荐操作
    RecommendedAction action = RecommendedAction.none;
    if (confidence > 70 && activityLevel == ActivityLevel.sleeping) {
      action = RecommendedAction.shortenTimer;
    } else if (confidence > 50 && activityLevel == ActivityLevel.resting) {
      action = RecommendedAction.maintainTimer;
    } else if (activityLevel == ActivityLevel.active || motionIntensity > 1.0) {
      // 检测到活跃状态，建议延长到30分钟（如果当前时长不足30分钟）
      action = RecommendedAction.extendToMinimum;
    } else if (motionIntensity > 0.8) {
      action = RecommendedAction.extendTimer;
    }

    return SleepDetectionResult(
      isSleeping: confidence > 60 && activityLevel == ActivityLevel.sleeping,
      confidence: confidence,
      activityLevel: activityLevel,
      recommendedAction: action,
      analysisDetails:
          '运动强度: ${motionIntensity.toStringAsFixed(2)}, '
          '变化幅度: ${motionVariability.toStringAsFixed(2)}, '
          '静止时段: $stillPeriods, '
          '时间权重: ${timeWeight.toStringAsFixed(1)}',
    );
  }

  /// 获取当前监听状态
  bool get isMonitoring => _isMonitoring;

  /// 获取权限状态
  bool get hasPermission => _hasPermission && _sensorsAvailable;

  /// 获取详细状态信息
  String get statusInfo {
    if (_initializationError.isNotEmpty) {
      return _initializationError;
    }

    if (!_hasPermission) {
      return '权限不足';
    }

    if (!_sensorsAvailable) {
      return '传感器不可用';
    }

    return _isMonitoring ? '监听中' : '已就绪';
  }

  /// 获取传感器可用性
  bool get sensorsAvailable => _sensorsAvailable;

  /// 公共方法：测试传感器可用性
  Future<bool> testSensorsAvailability() async {
    final result = await _testSensorsAvailability();
    _sensorsAvailable = result;
    notifyListeners();
    return result;
  }

  /// 强制更新权限状态
  void forceUpdatePermissionStatus(bool hasPermission, bool sensorsAvailable) {
    _hasPermission = hasPermission;
    _sensorsAvailable = sensorsAvailable;
    _initializationError = '';
    notifyListeners();
    AppLogger.info('强制更新权限状态: 权限=$hasPermission, 传感器=$sensorsAvailable');
  }

  /// 释放资源
  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// 睡眠检测结果
class SleepDetectionResult {
  final bool isSleeping;
  final double confidence; // 置信度 0-100
  final ActivityLevel activityLevel;
  final RecommendedAction recommendedAction;
  final String analysisDetails;

  SleepDetectionResult({
    required this.isSleeping,
    required this.confidence,
    required this.activityLevel,
    required this.recommendedAction,
    required this.analysisDetails,
  });

  @override
  String toString() {
    return 'SleepDetectionResult(sleeping: $isSleeping, '
        'confidence: ${confidence.toStringAsFixed(1)}%, '
        'activity: $activityLevel, '
        'action: $recommendedAction)';
  }
}

/// 活动等级
enum ActivityLevel {
  unknown, // 未知
  sleeping, // 睡眠中
  resting, // 休息中
  light, // 轻微活动
  active, // 活跃状态
}

/// 推荐操作
enum RecommendedAction {
  none, // 无操作
  shortenTimer, // 缩短定时器
  maintainTimer, // 保持定时器
  extendTimer, // 延长定时器
  extendToMinimum, // 延长到最少30分钟
}
