import 'package:flutter/material.dart';

/// 搜索框配置类
/// 用于统一管理应用中所有搜索框的外观样式
class SearchBarConfig {
  // 搜索框尺寸
  static const double height = 40.0;
  static const double borderRadius = 20.0;
  static const double iconSize = 20.0;
  static const double fontSize = 14.0;
  
  // 搜索框内边距
  static const EdgeInsetsGeometry contentPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 16);
  static const EdgeInsetsGeometry horizontalPadding = EdgeInsets.symmetric(horizontal: 12);
  
  // 图标和文本间距
  static const double iconTextSpacing = 8.0;
  
  /// 获取搜索框容器装饰样式
  static BoxDecoration getContainerDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      ),
    );
  }
  
  /// 获取搜索框输入装饰样式
  static InputDecoration getInputDecoration(BuildContext context, {
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: fontSize,
        fontWeight: FontWeight.normal,
      ),
      prefixIcon: Icon(
        Icons.search, 
        size: iconSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      contentPadding: contentPadding,
    );
  }
  
  /// 获取搜索图标样式
  static Icon getSearchIcon(BuildContext context) {
    return Icon(
      Icons.search,
      size: iconSize,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
  
  /// 获取占位文本样式
  static TextStyle getHintTextStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: fontSize,
      fontWeight: FontWeight.normal,
    );
  }
  
  /// 获取输入文本样式
  static TextStyle getInputTextStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: fontSize,
      fontWeight: FontWeight.normal,
    );
  }
}
