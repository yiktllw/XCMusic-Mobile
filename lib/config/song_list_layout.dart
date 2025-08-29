import 'package:flutter/material.dart';

/// 歌曲列表布局配置
/// 
/// 此文件定义了歌曲列表的通用布局数据，确保在不同页面（如歌单页面、主页推荐等）
/// 中保持一致的视觉样式和交互体验。
class SongListLayoutConfig {
  /// 歌曲项的高度
  static const double itemHeight = 64.0;
  
  /// 歌曲项的内边距
  static const EdgeInsets itemPadding = EdgeInsets.only(
    left: 8.0,
    right: 16.0,
    top: 8.0,
    bottom: 8.0,
  );
  
  /// 序号区域宽度
  static const double indexWidth = 34.0;
  
  /// 专辑封面尺寸
  static const double albumCoverSize = 40.0;
  
  /// 专辑封面圆角半径
  static const double albumCoverRadius = 4.0;
  
  /// 专辑封面参数（用于网络请求优化）
  static const String albumCoverParam = '?param=100y100';
  
  /// 元素间的间距
  static const double spacingSmall = 2.0;
  static const double spacingMedium = 12.0;
  
  /// VIP标识配置
  static const EdgeInsets vipPadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 1,
  );
  static const double vipRadius = 2.0;
  static const double vipFontSize = 10.0;
  
  /// 播放状态图标尺寸
  static const double playingIconSize = 20.0;
  
  /// 错误占位图标尺寸
  static const double errorIconSize = 24.0;
  
  /// 字体尺寸配置
  static const double songNameFontSize = 14.0;
  static const double indexFontSize = 12.0;
  static const double artistAlbumFontSize = 11.0;
  
  /// 字体权重配置
  static const FontWeight songNameFontWeight = FontWeight.normal;
  static const FontWeight playingSongNameFontWeight = FontWeight.w600;
  static const FontWeight indexFontWeight = FontWeight.normal;
  static const FontWeight artistAlbumFontWeight = FontWeight.normal;
  static const FontWeight vipFontWeight = FontWeight.bold;
}

/// 歌曲列表样式配置
/// 
/// 提供一致的文本样式和颜色配置
class SongListStyleConfig {
  /// 获取歌曲名称样式
  static TextStyle? getSongNameStyle(
    BuildContext context, {
    bool isCurrentPlaying = false,
  }) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge?.copyWith(
      color: isCurrentPlaying
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface,
      fontWeight: isCurrentPlaying
          ? SongListLayoutConfig.playingSongNameFontWeight
          : SongListLayoutConfig.songNameFontWeight,
      fontSize: SongListLayoutConfig.songNameFontSize,
    );
  }
  
  /// 获取序号样式
  static TextStyle? getIndexStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: SongListLayoutConfig.indexFontSize,
      fontWeight: SongListLayoutConfig.indexFontWeight,
    );
  }
  
  /// 获取艺术家和专辑样式
  static TextStyle? getArtistAlbumStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: SongListLayoutConfig.artistAlbumFontSize,
      fontWeight: SongListLayoutConfig.artistAlbumFontWeight,
    );
  }
  
  /// 获取播放状态图标颜色
  static Color getPlayingIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  /// 获取更多操作图标颜色
  static Color getMoreIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }
  
  /// 获取错误占位图标颜色
  static Color getErrorIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }
  
  /// 获取错误占位背景色
  static Color getErrorBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }
  
  /// VIP标识样式
  static const TextStyle vipTextStyle = TextStyle(
    color: Colors.white,
    fontSize: SongListLayoutConfig.vipFontSize,
    fontWeight: SongListLayoutConfig.vipFontWeight,
  );
  
  /// VIP标识背景色
  static const Color vipBackgroundColor = Colors.amber;
}
