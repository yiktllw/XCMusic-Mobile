import 'package:flutter/material.dart';
import 'floating_player_bar.dart';

/// 自动包装浮动播放栏的路由包装器
/// 通过路由系统自动为页面添加浮动播放栏，无需手动导入
class AutoFloatingPlayerWrapper extends StatelessWidget {
  final Widget child;
  final String? routeName;
  
  /// 不显示浮动播放栏的页面列表
  /// 这些页面要么本身就是播放器相关，要么不适合显示浮动播放栏
  static const Set<String> _excludedRoutes = {
    '/player',           // 播放器页面本身
    '/player_page',      // 播放器页面（备用路由名）
    '/login',            // 登录页面
    '/qr_login',         // 二维码登录页面  
    '/settings',         // 设置页面（如果是全屏设置）
    '/splash',           // 启动页面
    '/welcome',          // 欢迎页面
    '/onboarding',       // 引导页面
    // 可以根据需要添加更多排除的页面
  };
  
  /// 不显示浮动播放栏的页面类型
  /// 根据Widget的实际类型判断是否需要排除
  static const Set<String> _excludedPageTypeNames = {
    'PlayerPage',         // 播放器页面
    'QrLoginPage',        // 二维码登录页面
    'SplashPage',         // 启动页面（如果有）
    'WelcomePage',        // 欢迎页面（如果有）
    'OnboardingPage',     // 引导页面（如果有）
    'LoginPage',          // 登录页面（如果有）
    // 可以根据实际页面类型添加更多
  };
  
  /// 运行时添加的排除路由（允许动态添加）
  static final Set<String> _dynamicExcludedRoutes = <String>{};
  
  /// 运行时添加的排除页面类型（允许动态添加）
  static final Set<String> _dynamicExcludedPageTypes = <String>{};

  const AutoFloatingPlayerWrapper({
    super.key,
    required this.child,
    this.routeName,
  });
  
  /// 添加需要排除的路由
  static void addExcludedRoute(String routeName) {
    _dynamicExcludedRoutes.add(routeName);
  }
  
  /// 添加需要排除的页面类型
  static void addExcludedPageType(String pageTypeName) {
    _dynamicExcludedPageTypes.add(pageTypeName);
  }
  
  /// 移除排除的路由
  static void removeExcludedRoute(String routeName) {
    _dynamicExcludedRoutes.remove(routeName);
  }
  
  /// 移除排除的页面类型
  static void removeExcludedPageType(String pageTypeName) {
    _dynamicExcludedPageTypes.remove(pageTypeName);
  }
  
  /// 清空所有动态排除规则
  static void clearDynamicExclusions() {
    _dynamicExcludedRoutes.clear();
    _dynamicExcludedPageTypes.clear();
  }
  
  /// 获取所有排除的路由列表（用于调试）
  static Set<String> get allExcludedRoutes => {
    ..._excludedRoutes,
    ..._dynamicExcludedRoutes,
  };
  
  /// 获取所有排除的页面类型列表（用于调试）
  static Set<String> get allExcludedPageTypes => {
    ..._excludedPageTypeNames,
    ..._dynamicExcludedPageTypes,
  };

  @override
  Widget build(BuildContext context) {
    // 检查是否应该排除浮动播放栏
    final shouldExclude = _shouldExcludeFloatingPlayer();
    
    if (shouldExclude) {
      return child;
    }
    
    // 自动包装浮动播放栏
    return PageWithFloatingPlayer(
      body: child,
      showFloatingPlayer: true,
      adaptSafeArea: true,
      playerBottomOffset: 20,
      playerHorizontalPadding: 12,
    );
  }
  
  /// 判断是否应该排除浮动播放栏
  bool _shouldExcludeFloatingPlayer() {
    // 根据路由名排除（包括静态和动态）
    if (routeName != null && 
        (_excludedRoutes.contains(routeName) || _dynamicExcludedRoutes.contains(routeName))) {
      return true;
    }
    
    // 根据Widget类型名排除（包括静态和动态）
    final childTypeName = child.runtimeType.toString();
    if (_excludedPageTypeNames.contains(childTypeName) || 
        _dynamicExcludedPageTypes.contains(childTypeName)) {
      return true;
    }
    
    // 如果child已经是包含浮动播放栏的页面，避免重复包装
    if (child is PageWithFloatingPlayer) {
      return true;
    }
    
    return false;
  }
}

/// 扩展MaterialPageRoute以自动包装浮动播放栏
class AutoWrappedPageRoute<T> extends MaterialPageRoute<T> {
  final String? routeName;
  
  AutoWrappedPageRoute({
    required Widget Function(BuildContext) builder,
    super.settings,
    this.routeName,
    super.maintainState,
    super.fullscreenDialog,
  }) : super(
          builder: (context) => AutoFloatingPlayerWrapper(
            routeName: routeName ?? settings?.name,
            child: builder(context),
          ),
        );
}

/// 便捷的路由构建器
class AutoRouteBuilder {
  /// 创建自动包装浮动播放栏的路由
  static Route<T> build<T extends Object?>(
    String routeName,
    Widget Function(BuildContext) builder, {
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return AutoWrappedPageRoute<T>(
      builder: builder,
      settings: settings ?? RouteSettings(name: routeName),
      routeName: routeName,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }
  
  /// 批量创建路由映射
  static Map<String, WidgetBuilder> createRoutesMap(
    Map<String, Widget Function(BuildContext)> routes,
  ) {
    return routes.map((routeName, builder) => MapEntry(
      routeName,
      (context) => AutoFloatingPlayerWrapper(
        routeName: routeName,
        child: builder(context),
      ),
    ));
  }
}
