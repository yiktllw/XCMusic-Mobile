import 'package:flutter/material.dart';

/// 全局导航服务
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 获取当前BuildContext
  BuildContext? get currentContext => navigatorKey.currentContext;

  /// 显示对话框
  Future<T?> showDialogGlobal<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final context = currentContext;
    if (context == null) return null;
    
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// 导航到页面
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) async {
    final context = currentContext;
    if (context == null) return null;
    
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// 导航到页面（使用路由对象）
  Future<T?> push<T>(Route<T> route) async {
    final context = currentContext;
    if (context == null) return null;
    
    return Navigator.of(context).push<T>(route);
  }
}
