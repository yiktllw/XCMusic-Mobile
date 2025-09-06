import 'package:flutter/material.dart';
import '../services/sleep_timer_service.dart';
import '../pages/sleep_timer_page.dart';

/// 夜间定时关闭询问对话框
class NightModeAskDialog extends StatelessWidget {
  const NightModeAskDialog({super.key});

  /// 显示夜间询问对话框
  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NightModeAskDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sleepTimerService = SleepTimerService();
    
    return AlertDialog(
      icon: Icon(
        Icons.bedtime,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        '夜间播放提醒',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '现在是夜间时段（${sleepTimerService.nightTimeDescription}），是否要设置定时关闭？',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '设置定时关闭可以避免整夜播放，有助于更好的睡眠质量',
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
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('暂不设置'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            // 直接导航，不使用延迟
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SleepTimerPage(),
              ),
            );
          },
          child: const Text('设置定时关闭'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceEvenly,
    );
  }
}
