import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sleep_timer_service.dart';

/// 定时关闭设置页面
class SleepTimerPage extends StatefulWidget {
  const SleepTimerPage({super.key});

  @override
  State<SleepTimerPage> createState() => _SleepTimerPageState();
}

class _SleepTimerPageState extends State<SleepTimerPage> {
  final TextEditingController _customTimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 页面初始化时刷新智能检测状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepTimerService>().refreshSmartDetectionStatus();
    });
  }

  @override
  void dispose() {
    _customTimeController.dispose();
    super.dispose();
  }

  void _showCustomTimeDialog(SleepTimerService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '自定义时长',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: TextField(
          controller: _customTimeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '时长（分钟）',
            hintText: '请输入1-180之间的数字',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = _customTimeController.text.trim();
              if (text.isNotEmpty) {
                final minutes = int.tryParse(text);
                if (minutes != null && minutes > 0 && minutes <= 180) {
                  service.setTimer(minutes);
                  Navigator.pop(context);
                  _customTimeController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入1-180之间的有效数字')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showTimePicker(BuildContext context, SleepTimerService service, 
                      bool isStartTime, int initialHour, int initialMinute) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    ).then((selectedTime) {
      if (selectedTime != null) {
        if (isStartTime) {
          service.setNightStartTime(selectedTime.hour, selectedTime.minute);
        } else {
          service.setNightEndTime(selectedTime.hour, selectedTime.minute);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SleepTimerService>(
      builder: (context, service, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('定时关闭'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前状态显示
                if (service.isActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 48,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.smartTimer ? '智能关闭已启用' : '定时关闭已启用',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.smartTimer 
                            ? '智能检测睡眠状态，预计剩余：${service.remainingTimeString}'
                            : '剩余时间：${service.remainingTimeString}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: service.cancel,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                          ),
                          child: const Text('取消定时关闭'),
                        ),
                      ],
                    ),
                  ),

                // 定时关闭主开关
                Text(
                  '定时关闭',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '启用定时关闭',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    service.smartTimer
                      ? '智能关闭已启用，固定定时功能已禁用'
                      : service.isActive 
                        ? '定时关闭已启用，剩余时间：${service.remainingTimeString}'
                        : '设置播放时长后自动停止音乐',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: service.isActive && !service.smartTimer,
                  onChanged: service.smartTimer ? null : (value) {
                    if (value) {
                      // 如果没有设置时长，使用上次设置的时长或默认30分钟
                      service.setTimer(service.lastSetMinutes > 0 ? service.lastSetMinutes : 30);
                    } else {
                      service.cancel();
                    }
                  },
                ),
                
                const SizedBox(height: 24),

                // 时长选择
                Text(
                  '选择时长',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: service.smartTimer 
                      ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)
                      : null,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 预设时长按钮
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTimeButton(service, 15),
                    _buildTimeButton(service, 30),
                    _buildTimeButton(service, 45),
                    _buildTimeButton(service, 60),
                    _buildTimeButton(service, 90),
                    _buildTimeButton(service, 120),
                    _buildCustomTimeButton(service),
                  ],
                ),
                
                const SizedBox(height: 24),

                // 播放设置
                Text(
                  '播放设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '播完当前歌曲再停止',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '定时器到时不会立即停止，而是等当前歌曲播放完毕',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: service.finishCurrentSong,
                  onChanged: service.setFinishCurrentSong,
                ),
                
                const SizedBox(height: 16),
                
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '智能关闭',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.hasSmartDetection
                          ? '通过传感器智能检测睡眠状态，自动调整关闭时间（启用后固定定时功能将被禁用）'
                          : '传感器状态：${service.smartDetectionStatus}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: service.hasSmartDetection 
                            ? null 
                            : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (!service.hasSmartDetection) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pushNamed('/sensor_permission');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '检查权限设置',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  value: service.smartTimer,
                  onChanged: service.hasSmartDetection ? service.setSmartTimer : null,
                ),
                
                // 智能关闭说明
                if (service.smartTimer)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              service.isSmartDetectionRunning
                                ? Icons.sensors
                                : Icons.sensors_off,
                              size: 16,
                              color: service.isSmartDetectionRunning
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '智能关闭功能：',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: service.isSmartDetectionRunning
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                service.isSmartDetectionRunning ? '监听中' : '离线',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: service.isSmartDetectionRunning
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 使用加速度传感器和陀螺仪实时监测设备运动状态',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 当检测到持续静止状态时智能缩短定时时间',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 根据时间段和运动数据动态调整关闭时机',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 避免因翻身等轻微动作误判为清醒状态',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!service.hasSmartDetection) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  service.sensorsAvailable ? Icons.lock : Icons.sensors_off,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '状态：${service.smartDetectionStatus}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/sensor-permission');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: Text(
                                    service.sensorsAvailable ? '权限设置' : '查看详情',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // 夜间询问设置
                Text(
                  '夜间设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '夜间播放提醒',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '在夜间时段开始播放时询问是否设置定时关闭',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: service.nightModeAsk,
                  onChanged: service.setNightModeAsk,
                ),
                
                // 夜间时段设置
                if (service.nightModeAsk)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '夜间时段设置：',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 开始时间设置
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('开始时间'),
                          trailing: TextButton(
                            onPressed: () => _showTimePicker(
                              context, 
                              service, 
                              true,
                              service.nightStartHour,
                              service.nightStartMinute,
                            ),
                            child: Text(
                              '${service.nightStartHour.toString().padLeft(2, '0')}:${service.nightStartMinute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        
                        // 结束时间设置
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('结束时间'),
                          trailing: TextButton(
                            onPressed: () => _showTimePicker(
                              context, 
                              service, 
                              false,
                              service.nightEndHour,
                              service.nightEndMinute,
                            ),
                            child: Text(
                              '${service.nightEndHour.toString().padLeft(2, '0')}:${service.nightEndMinute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          '当前夜间时段：${service.nightTimeDescription}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (service.isInNightTime())
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '现在正处于夜间时段',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeButton(SleepTimerService service, int minutes) {
    final isSelected = service.isActive && service.lastSetMinutes == minutes && !service.smartTimer;
    final isDisabled = service.smartTimer;
    
    return SizedBox(
      height: 48,
      child: FilledButton.tonal(
        onPressed: isDisabled ? null : () => service.setTimer(minutes),
        style: FilledButton.styleFrom(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary
              : isDisabled
                ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : isDisabled
                ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text('$minutes分钟'),
      ),
    );
  }

  Widget _buildCustomTimeButton(SleepTimerService service) {
    final isDisabled = service.smartTimer;
    
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: isDisabled ? null : () => _showCustomTimeDialog(service),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: isDisabled
            ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)
            : null,
          side: isDisabled 
            ? BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5))
            : null,
        ),
        child: const Text('自定义'),
      ),
    );
  }
}
