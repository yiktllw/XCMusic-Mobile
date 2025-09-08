import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import 'player_service.dart';
import 'smart_detection_service.dart';

/// 定时关闭服务
class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal();

  Timer? _timer;
  DateTime? _endTime;
  bool _isActive = false;
  bool _finishCurrentSong = true;
  bool _smartTimer = false;
  int _lastSetMinutes = 30;
  
  // 夜间询问相关设置
  bool _nightModeAsk = false;
  int _nightStartHour = 22;  // 晚上10点
  int _nightStartMinute = 0;
  int _nightEndHour = 7;     // 早上7点
  int _nightEndMinute = 0;

  PlayerService? _playerService;
  SmartDetectionService? _smartDetectionService;

  // Getters
  bool get isActive => _isActive;
  bool get finishCurrentSong => _finishCurrentSong;
  bool get smartTimer => _smartTimer && _isActive;
  int get lastSetMinutes => _lastSetMinutes;
  
  // 夜间询问相关getters
  bool get nightModeAsk => _nightModeAsk;
  int get nightStartHour => _nightStartHour;
  int get nightStartMinute => _nightStartMinute;
  int get nightEndHour => _nightEndHour;
  int get nightEndMinute => _nightEndMinute;

  /// 剩余时间字符串
  String get remainingTimeString {
    if (!_isActive || _endTime == null) return '';
    
    final now = DateTime.now();
    final remaining = _endTime!.difference(now);
    
    if (remaining.isNegative) return '00:00';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 状态描述字符串
  String get statusDescription {
    if (!_isActive) return '定时关闭未启用';
    
    if (_smartTimer) {
      return '智能关闭已启用，预计剩余时间：$remainingTimeString';
    } else {
      return '定时关闭已启用，剩余时间：$remainingTimeString';
    }
  }

  /// 获取智能检测状态
  bool get hasSmartDetection => _smartDetectionService?.hasPermission ?? false;
  
  /// 获取智能检测运行状态
  bool get isSmartDetectionRunning => _smartDetectionService?.isMonitoring ?? false;
  
  /// 获取智能检测状态信息
  String get smartDetectionStatus => _smartDetectionService?.statusInfo ?? '未初始化';
  
  /// 获取传感器权限状态
  bool get sensorPermissionGranted => _smartDetectionService?.hasPermission ?? false;
  
  /// 获取传感器可用性
  bool get sensorsAvailable => _smartDetectionService?.sensorsAvailable ?? false;
  
  /// 刷新智能检测状态
  Future<void> refreshSmartDetectionStatus() async {
    try {
      await _smartDetectionService?.initialize();
      AppLogger.info('智能检测状态已刷新');
    } catch (e) {
      AppLogger.error('刷新智能检测状态失败', e);
    }
  }

  /// 初始化服务
  Future<void> initialize() async {
    try {
      await _loadSettings();
      
      // 初始化智能检测服务
      _smartDetectionService = SmartDetectionService();
      
      // 监听智能检测服务状态变化
      _smartDetectionService?.addListener(_onSmartDetectionStateChanged);
      
      await _smartDetectionService!.initialize();
      
      AppLogger.info('定时关闭服务初始化完成');
    } catch (e) {
      AppLogger.error('定时关闭服务初始化失败', e);
    }
  }
  
  /// 智能检测状态变化回调
  void _onSmartDetectionStateChanged() {
    AppLogger.info('智能检测状态发生变化');
    
    // 检查智能关闭是否仍然可用
    if (_smartTimer && !hasSmartDetection) {
      AppLogger.info('智能检测不可用，自动禁用智能关闭');
      _smartTimer = false;
      _isActive = false;
      _timer?.cancel();
      _timer = null;
      _endTime = null;
      _saveSettings();
    }
    
    // 通知UI更新
    notifyListeners();
  }

  /// 设置播放器服务引用
  void setPlayerService(PlayerService playerService) {
    _playerService = playerService;
  }

  /// 设置定时器
  void setTimer(int minutes) {
    if (minutes <= 0) return;
    
    // 如果智能关闭已启用，禁用固定定时功能
    if (_smartTimer) {
      AppLogger.warning('智能关闭已启用，无法设置固定定时器');
      return;
    }
    
    _lastSetMinutes = minutes;
    _endTime = DateTime.now().add(Duration(minutes: minutes));
    _isActive = true;
    
    _saveSettings();
    _startTimer();
    
    AppLogger.info('设置定时关闭: $minutes分钟');
    notifyListeners();
  }

  /// 取消定时器
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _endTime = null;
    _isActive = false;
    
    // 停止智能监听
    if (_smartTimer) {
      _smartDetectionService?.stopMonitoring();
      AppLogger.info('已停止智能监听');
    }
    
    _saveSettings();
    
    AppLogger.info('取消定时关闭');
    notifyListeners();
  }

  /// 设置播完整首歌再停止
  void setFinishCurrentSong(bool value) {
    _finishCurrentSong = value;
    _saveSettings();
    notifyListeners();
  }

  /// 设置智能关闭
  void setSmartTimer(bool value) {
    _smartTimer = value;
    
    if (value) {
      // 启用智能关闭时，取消现有的固定定时器
      if (_isActive) {
        _timer?.cancel();
        _timer = null;
        _endTime = null;
        AppLogger.info('启用智能关闭，已取消固定定时器');
      }
      
      // 启动智能关闭模式
      _isActive = true;
      _applySmartTimerLogic();
      
      // 记录传感器状态
      if (_smartDetectionService != null) {
        final hasPermission = _smartDetectionService!.hasPermission;
        final sensorsAvailable = _smartDetectionService!.sensorsAvailable;
        final statusInfo = _smartDetectionService!.statusInfo;
        AppLogger.info('智能关闭已启用 - 传感器状态: 权限=$hasPermission, 可用=$sensorsAvailable, 详情=$statusInfo');
      } else {
        AppLogger.info('智能关闭已启用 - 传感器服务未初始化');
      }
    } else {
      // 禁用智能关闭时，也取消定时器状态
      _isActive = false;
      _timer?.cancel();
      _timer = null;
      _endTime = null;
      
      // 停止智能监听
      _smartDetectionService?.stopMonitoring();
      
      AppLogger.info('智能关闭已禁用');
    }
    
    _saveSettings();
    notifyListeners();
  }

  /// 设置夜间询问
  void setNightModeAsk(bool value) {
    _nightModeAsk = value;
    _saveSettings();
    notifyListeners();
  }

  /// 设置夜间时段开始时间
  void setNightStartTime(int hour, int minute) {
    _nightStartHour = hour.clamp(0, 23);
    _nightStartMinute = minute.clamp(0, 59);
    _saveSettings();
    notifyListeners();
  }

  /// 设置夜间时段结束时间
  void setNightEndTime(int hour, int minute) {
    _nightEndHour = hour.clamp(0, 23);
    _nightEndMinute = minute.clamp(0, 59);
    _saveSettings();
    notifyListeners();
  }

  /// 检查当前是否在夜间时段
  bool isInNightTime([DateTime? checkTime]) {
    if (!_nightModeAsk) return false;
    
    final now = checkTime ?? DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _nightStartHour * 60 + _nightStartMinute;
    final endMinutes = _nightEndHour * 60 + _nightEndMinute;
    
    if (startMinutes <= endMinutes) {
      // 同一天内的时间段，如 9:00-17:00
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // 跨天的时间段，如 22:00-07:00
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  /// 获取夜间时段描述文本
  String get nightTimeDescription {
    final startTime = '${_nightStartHour.toString().padLeft(2, '0')}:${_nightStartMinute.toString().padLeft(2, '0')}';
    final endTime = '${_nightEndHour.toString().padLeft(2, '0')}:${_nightEndMinute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }

  /// 检查是否应该询问设置定时关闭
  bool shouldAskForSleepTimer() {
    return _nightModeAsk && isInNightTime() && !_isActive;
  }

  /// 启动定时器
  void _startTimer() {
    _timer?.cancel();
    
    // 每秒更新一次，用于显示剩余时间
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_endTime == null) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      if (now.isAfter(_endTime!)) {
        _onTimerExpired();
        timer.cancel();
      } else {
        // 通知UI更新剩余时间显示
        notifyListeners();
      }
    });
  }

  /// 定时器到时处理
  void _onTimerExpired() {
    AppLogger.info('定时关闭时间到');
    
    if (_finishCurrentSong && _playerService?.isPlaying == true) {
      // 设置播放完当前歌曲后停止
      AppLogger.info('设置播放完当前歌曲后停止');
      _playerService!.setShouldStopAfterCurrentTrack(true);
    } else {
      // 立即停止播放
      _stopPlayback();
    }
  }

  /// 停止播放
  void _stopPlayback() {
    try {
      _playerService?.stop(); // 使用stop()而不是pause()
      _isActive = false;
      _endTime = null;
      _timer?.cancel();
      _timer = null;
      
      _saveSettings();
      notifyListeners();
      
      AppLogger.info('定时关闭执行完成，已停止播放');
    } catch (e) {
      AppLogger.error('停止播放时出错', e);
    }
  }

  /// 应用智能定时器逻辑
  void _applySmartTimerLogic() {
    // 智能关闭的实现方案：
    
    // 主要方案: 结合加速度传感器检测睡眠状态
    // 通过加速度传感器检测用户活动状态，活动减少时调整定时
    // 实现思路：
    // 1. 使用 sensors_plus 包监听加速度数据
    // 2. 计算设备运动的强度和频率
    // 3. 设定阈值判断静止状态（如连续5分钟运动幅度小于0.1g）
    // 4. 当检测到持续静止时，缩短定时关闭时间
    // 5. 使用滑动窗口算法避免翻身等轻微动作的误判
    // 6. 结合时间因素，夜间时段降低阈值敏感度
    
    // 辅助方案1: 根据系统勿扰模式自动调整
    // 检测系统是否开启勿扰模式，如果开启则缩短定时时间
    // 实现思路：通过原生平台代码检测勿扰模式状态
    
    // 辅助方案2: 学习用户使用习惯智能预测
    // 记录用户通常的睡眠时间，智能推荐定时关闭时长
    // 实现思路：收集用户历史使用数据，使用机器学习预测
    
    // 辅助方案3: 检测环境音量变化判断入睡
    // 通过麦克风检测环境音量，当音量持续降低时判断用户可能入睡
    // 实现思路：使用AudioSession监听环境音量变化
    
    // 记录传感器状态
    if (_smartDetectionService != null) {
      final hasPermission = _smartDetectionService!.hasPermission;
      final sensorsAvailable = _smartDetectionService!.sensorsAvailable;
      final statusInfo = _smartDetectionService!.statusInfo;
      AppLogger.info('智能关闭模式启动 - 传感器状态: 权限=$hasPermission, 可用=$sensorsAvailable, 详情=$statusInfo');
    } else {
      AppLogger.info('智能关闭模式启动 - 传感器服务未初始化');
    }
    
    // 智能关闭模式：根据时间段设置基础定时，后续根据传感器数据动态调整
    _startSmartTimer();
  }

  /// 启动智能定时器
  void _startSmartTimer() {
    final currentHour = DateTime.now().hour;
    int baseMinutes;
    
    // 根据时间段设置基础定时时长
    if ((currentHour >= 22) || (currentHour <= 6)) {
      // 夜间时段：45-90分钟
      baseMinutes = 60;
    } else if (currentHour >= 12 && currentHour <= 14) {
      // 午休时段：30-45分钟
      baseMinutes = 35;
    } else {
      // 其他时段：60-120分钟
      baseMinutes = 90;
    }
    
    _lastSetMinutes = baseMinutes;
    _endTime = DateTime.now().add(Duration(minutes: baseMinutes));
    
    AppLogger.info('智能关闭设置基础定时: $baseMinutes分钟');
    
    // 启动智能监听逻辑
    _startSmartMonitoring();
    
    // 启动常规定时器用于时间更新
    _startTimer();
  }

  /// 启动智能监听
  void _startSmartMonitoring() {
    if (_smartDetectionService == null || !_smartDetectionService!.hasPermission) {
      AppLogger.warning('智能检测服务不可用，使用基础定时模式');
      return;
    }

    // 启动智能检测
    _smartDetectionService!.startMonitoring(
      onSleepDetected: _onSleepDetected,
    );
    
    AppLogger.info('智能监听已启动');
  }

  /// 处理睡眠检测结果
  void _onSleepDetected(SleepDetectionResult result) {
    if (!_isActive || !_smartTimer) return;

    AppLogger.info('检测到睡眠状态: ${result.toString()}');

    // 根据检测结果调整定时器
    switch (result.recommendedAction) {
      case RecommendedAction.shortenTimer:
        _adjustTimer(0.7); // 缩短到70%
        break;
      case RecommendedAction.extendTimer:
        _adjustTimer(1.3); // 延长30%
        break;
      case RecommendedAction.extendToMinimum:
        _ensureMinimumTime(30); // 确保至少30分钟
        break;
      case RecommendedAction.maintainTimer:
        // 保持当前定时器不变
        AppLogger.info('智能检测建议保持当前定时器');
        break;
      case RecommendedAction.none:
        // 无操作
        break;
    }

    // 通知UI更新（如果需要显示检测状态）
    notifyListeners();
  }

  /// 调整定时器时长
  void _adjustTimer(double factor) {
    if (_endTime == null) return;

    final now = DateTime.now();
    final currentRemaining = _endTime!.difference(now);
    
    if (currentRemaining.isNegative) return;

    // 计算新的剩余时间
    final newRemaining = Duration(
      milliseconds: (currentRemaining.inMilliseconds * factor).round(),
    );

    // 设置新的结束时间
    _endTime = now.add(newRemaining);
    
    // 更新记录的时长
    _lastSetMinutes = newRemaining.inMinutes;

    final actionDesc = factor < 1.0 ? '缩短' : '延长';
    AppLogger.info('智能调整定时器: $actionDesc至${newRemaining.inMinutes}分钟');
    
    // 保存设置
    _saveSettings();
    
    // 通知UI更新
    notifyListeners();
  }

  /// 确保定时器至少有指定的分钟数
  void _ensureMinimumTime(int minimumMinutes) {
    if (_endTime == null) return;

    final now = DateTime.now();
    final currentRemaining = _endTime!.difference(now);
    
    if (currentRemaining.isNegative) return;

    final currentRemainingMinutes = currentRemaining.inMinutes;
    
    // 如果当前剩余时间已经足够，则不做调整
    if (currentRemainingMinutes >= minimumMinutes) {
      AppLogger.info('当前剩余时间$currentRemainingMinutes分钟已足够，无需延长到$minimumMinutes分钟');
      return;
    }

    // 设置新的结束时间为当前时间 + 最小分钟数
    _endTime = now.add(Duration(minutes: minimumMinutes));
    
    // 更新记录的时长
    _lastSetMinutes = minimumMinutes;

    AppLogger.info('智能延长定时器: 从$currentRemainingMinutes分钟延长到$minimumMinutes分钟');
    
    // 保存设置
    _saveSettings();
    
    // 通知UI更新
    notifyListeners();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _finishCurrentSong = prefs.getBool('sleep_timer_finish_current_song') ?? true;
      _smartTimer = prefs.getBool('sleep_timer_smart_timer') ?? false;
      _lastSetMinutes = prefs.getInt('sleep_timer_last_set_minutes') ?? 30;
      
      // 加载夜间询问设置
      _nightModeAsk = prefs.getBool('sleep_timer_night_mode_ask') ?? false;
      _nightStartHour = prefs.getInt('sleep_timer_night_start_hour') ?? 22;
      _nightStartMinute = prefs.getInt('sleep_timer_night_start_minute') ?? 0;
      _nightEndHour = prefs.getInt('sleep_timer_night_end_hour') ?? 7;
      _nightEndMinute = prefs.getInt('sleep_timer_night_end_minute') ?? 0;
    } catch (e) {
      AppLogger.error('加载定时关闭设置失败', e);
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sleep_timer_finish_current_song', _finishCurrentSong);
      await prefs.setBool('sleep_timer_smart_timer', _smartTimer);
      await prefs.setInt('sleep_timer_last_set_minutes', _lastSetMinutes);
      
      // 保存夜间询问设置
      await prefs.setBool('sleep_timer_night_mode_ask', _nightModeAsk);
      await prefs.setInt('sleep_timer_night_start_hour', _nightStartHour);
      await prefs.setInt('sleep_timer_night_start_minute', _nightStartMinute);
      await prefs.setInt('sleep_timer_night_end_hour', _nightEndHour);
      await prefs.setInt('sleep_timer_night_end_minute', _nightEndMinute);
    } catch (e) {
      AppLogger.error('保存定时关闭设置失败', e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smartDetectionService?.removeListener(_onSmartDetectionStateChanged);
    _smartDetectionService?.dispose();
    super.dispose();
  }
}
