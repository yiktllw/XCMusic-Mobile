# 自动浮动播放栏包装器使用说明

## 概述
`AutoFloatingPlayerWrapper` 是一个自动为应用页面添加浮动播放栏的路由包装系统，无需在每个页面中手动导入和使用浮动播放栏组件。

## 功能特性

### 自动包装
- 所有通过路由系统导航的页面都会自动包含浮动播放栏
- 支持safe area适配
- 自动处理底部间距以避免与播放栏重叠

### 智能排除
系统会自动排除以下类型的页面：
1. 播放器页面本身（避免重复显示）
2. 登录相关页面
3. 设置页面
4. 启动页面和引导页面

### 动态配置
支持运行时动态添加或移除排除规则。

## 使用方法

### 基本使用
系统已经在 `main.dart` 中配置完成，无需额外操作。所有页面都会自动包含浮动播放栏。

### 添加排除页面
如果需要排除特定页面，可以使用以下方法：

#### 1. 按路由名排除
```dart
// 添加排除路由
AutoFloatingPlayerWrapper.addExcludedRoute('/my_custom_page');

// 移除排除路由
AutoFloatingPlayerWrapper.removeExcludedRoute('/my_custom_page');
```

#### 2. 按页面类型排除
```dart
// 添加排除的页面类型
AutoFloatingPlayerWrapper.addExcludedPageType('MyCustomPage');

// 移除排除的页面类型
AutoFloatingPlayerWrapper.removeExcludedPageType('MyCustomPage');
```

#### 3. 清空所有动态排除规则
```dart
AutoFloatingPlayerWrapper.clearDynamicExclusions();
```

### 查看当前排除列表
```dart
// 获取所有排除的路由
Set<String> excludedRoutes = AutoFloatingPlayerWrapper.allExcludedRoutes;

// 获取所有排除的页面类型
Set<String> excludedPageTypes = AutoFloatingPlayerWrapper.allExcludedPageTypes;
```

## 默认排除列表

### 排除的路由
- `/player` - 播放器页面
- `/player_page` - 播放器页面（备用）
- `/login` - 登录页面
- `/qr_login` - 二维码登录页面
- `/settings` - 设置页面
- `/splash` - 启动页面
- `/welcome` - 欢迎页面
- `/onboarding` - 引导页面

### 排除的页面类型
- `PlayerPage` - 播放器页面
- `QrLoginPage` - 二维码登录页面
- `SplashPage` - 启动页面
- `WelcomePage` - 欢迎页面
- `OnboardingPage` - 引导页面
- `LoginPage` - 登录页面

## 配置示例

### 在应用启动时配置排除规则
```dart
void main() async {
  // 添加自定义排除页面
  AutoFloatingPlayerWrapper.addExcludedRoute('/video_player');
  AutoFloatingPlayerWrapper.addExcludedPageType('VideoPlayerPage');
  
  runApp(MyApp());
}
```

### 在特定条件下动态调整
```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 根据用户偏好或其他条件动态调整
    if (userPrefersNoPlayerBar) {
      AutoFloatingPlayerWrapper.addExcludedRoute('/music_library');
    }
    
    return MaterialApp(
      // ... 其他配置
    );
  }
}
```

## 技术实现

### 路由系统集成
系统通过以下方式集成到路由中：
1. `routes` 映射使用 `AutoRouteBuilder.createRoutesMap()` 创建
2. `onGenerateRoute` 使用 `AutoWrappedPageRoute` 包装页面
3. 所有页面都经过 `AutoFloatingPlayerWrapper` 处理

### 智能检测
系统会检测以下情况并自动排除：
1. 路由名匹配排除列表
2. 页面类型匹配排除列表
3. 页面已经是 `PageWithFloatingPlayer` 类型
4. 页面已经包含 Stack 布局（可能已有浮动组件）

## 注意事项

1. **避免重复包装**：系统会自动检测并避免重复添加浮动播放栏
2. **安全区域适配**：所有包装的页面都会自动适配安全区域
3. **性能考虑**：系统只在必要时添加包装，不会影响不需要浮动播放栏的页面
4. **调试支持**：可以通过 `allExcludedRoutes` 和 `allExcludedPageTypes` 查看当前配置

## 故障排除

### 页面仍然显示浮动播放栏
1. 检查页面类型是否在排除列表中
2. 检查路由名是否正确
3. 使用动态添加方法手动排除

### 页面没有显示浮动播放栏
1. 确认页面不在排除列表中
2. 检查页面是否已经包含自定义的浮动组件
3. 查看控制台是否有相关错误信息
