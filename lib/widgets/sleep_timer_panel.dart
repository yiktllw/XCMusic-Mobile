import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sleep_timer_service.dart';

/// 定时关闭面板
class SleepTimerPanel extends StatefulWidget {
  const SleepTimerPanel({super.key});

  /// 显示定时关闭面板
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const SleepTimerPanel(),
      ),
    );
  }

  @override
  State<SleepTimerPanel> createState() => _SleepTimerPanelState();
}

class _SleepTimerPanelState extends State<SleepTimerPanel> {
  final TextEditingController _customTimeController = TextEditingController();

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
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: '分钟',
            labelStyle: Theme.of(context).textTheme.bodySmall,
            hintText: '请输入分钟数',
            hintStyle: Theme.of(context).textTheme.bodySmall,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(_customTimeController.text);
              if (minutes != null && minutes > 0) {
                service.setTimer(minutes);
                Navigator.pop(context);
                _customTimeController.clear();
              }
            },
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
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
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '定时关闭',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 定时关闭开关
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(
                    '定时关闭',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: service.isActive 
                      ? Text(
                          '剩余时间: ${service.remainingTimeString}',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Text(
                          '当前未设置定时关闭',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  value: service.isActive,
                  onChanged: (value) {
                    if (value) {
                      // 开启时使用上次设置的时间或默认30分钟
                      service.setTimer(service.lastSetMinutes);
                    } else {
                      service.cancel();
                    }
                  },
                ),
                
                const Divider(),
                
                // 时间选择按钮
                Text(
                  '选择时长',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 预设时间按钮
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final minutes in [10, 20, 30, 45, 60, 90])
                      _buildTimeButton(service, minutes),
                    _buildCustomTimeButton(service),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 播完整首歌再停止开关
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(
                    '播完整首歌再停止',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '到时后等当前歌曲播放完毕再停止',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: service.finishCurrentSong,
                  onChanged: service.setFinishCurrentSong,
                ),
                
                const Divider(),
                
                // 智能关闭开关
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(
                    '智能关闭',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '通过加速度传感器检测睡眠状态智能调整定时',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: service.smartTimer,
                  onChanged: service.setSmartTimer,
                ),
                
                // 智能关闭说明
                if (service.smartTimer)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '智能关闭功能：',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• 使用加速度传感器实时监测设备运动状态',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 当检测到持续静止状态时判断用户可能入睡',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 根据运动数据智能调整定时关闭时间',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '• 避免因翻身等轻微动作误判为清醒状态',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '注意：此功能需要允许应用访问设备传感器',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // 夜间询问开关
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
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
                    margin: const EdgeInsets.only(top: 8),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '开始时间：',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => _showTimePicker(
                                context, 
                                service, 
                                true,
                                service.nightStartHour,
                                service.nightStartMinute,
                              ),
                              child: Text(
                                '${service.nightStartHour.toString().padLeft(2, '0')}:${service.nightStartMinute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // 结束时间设置
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '结束时间：',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => _showTimePicker(
                                context, 
                                service, 
                                false,
                                service.nightEndHour,
                                service.nightEndMinute,
                              ),
                              child: Text(
                                '${service.nightEndHour.toString().padLeft(2, '0')}:${service.nightEndMinute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
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
                          Text(
                            '现在正处于夜间时段',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        )
        );
      },
    );
  }

  Widget _buildTimeButton(SleepTimerService service, int minutes) {
    final isSelected = service.isActive && service.lastSetMinutes == minutes;
    
    return SizedBox(
      height: 32,
      child: FilledButton.tonal(
        onPressed: () => service.setTimer(minutes),
        style: FilledButton.styleFrom(
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        child: Text('$minutes分钟'),
      ),
    );
  }

  Widget _buildCustomTimeButton(SleepTimerService service) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () => _showCustomTimeDialog(service),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        child: const Text('自定义'),
      ),
    );
  }
}
