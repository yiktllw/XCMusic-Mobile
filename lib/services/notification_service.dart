import 'package:flutter/material.dart';

/// 通知类型枚举
enum NotificationType { success, error, warning, info }

/// 通知服务类
/// 提供全局通知浮窗功能
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  OverlayEntry? _currentEntry;

  /// 获取当前的Overlay状态
  OverlayState? _getOverlayState(BuildContext context) {
    return Overlay.of(context, rootOverlay: true);
  }

  /// 显示通知浮窗
  ///
  /// [message] 通知消息
  /// [type] 通知类型
  /// [context] 上下文，用于获取Overlay
  /// [duration] 显示时长，默认3秒
  void show(
    String message,
    BuildContext context, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      // 如果有现有通知，先移除
      _currentEntry?.remove();

      final overlayState = _getOverlayState(context);
      if (overlayState == null) {
        print('无法获取Overlay，无法显示通知: $message');
        return;
      }

      // 创建新的通知Entry
      _currentEntry = OverlayEntry(
        builder: (context) => _NotificationWidget(
          message: message,
          type: type,
          onDismiss: () {
            _currentEntry?.remove();
            _currentEntry = null;
          },
        ),
      );

      // 显示通知
      overlayState.insert(_currentEntry!);

      // 自动隐藏
      Future.delayed(duration, () {
        _currentEntry?.remove();
        _currentEntry = null;
      });
    } catch (e) {
      print('显示通知时出错: $e');
    }
  }

  /// 显示成功通知
  void showSuccess(String message, BuildContext context, {Duration? duration}) {
    show(
      message,
      context,
      type: NotificationType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// 显示错误通知
  void showError(String message, BuildContext context, {Duration? duration}) {
    show(
      message,
      context,
      type: NotificationType.error,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// 显示警告通知
  void showWarning(String message, BuildContext context, {Duration? duration}) {
    show(
      message,
      context,
      type: NotificationType.warning,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// 显示信息通知
  void showInfo(String message, BuildContext context, {Duration? duration}) {
    show(
      message,
      context,
      type: NotificationType.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// 隐藏当前通知
  void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

/// 通知浮窗组件
class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 获取通知图标
  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  /// 获取通知颜色
  Color _getColor() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  /// 关闭通知
  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: _getColor(), width: 1),
              ),
              child: Row(
                children: [
                  Icon(_getIcon(), color: _getColor(), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
