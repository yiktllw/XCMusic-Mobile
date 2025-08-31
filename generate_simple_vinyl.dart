#!/usr/bin/env dart

/// 简化版黑胶唱片PNG生成器 - 确保透明背景
/// 专注于生成具有透明背景的环形黑胶图片

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  print('生成透明背景的黑胶唱片图片...');
  
  // 生成测试图片
  await generateTransparentVinyl(1024, 'assets/images/vinyl_ring_test.png');
  
  print('✅ 测试图片生成完成！');
}

Future<void> generateTransparentVinyl(int size, String outputPath) async {
  print('🎨 绘制透明黑胶: $size x $size');
  
  // 创建图片，并明确设置为透明背景
  final image = img.Image(width: size, height: size, numChannels: 4); // 确保有alpha通道
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0)); // 明确填充为完全透明
  
  final center = size / 2;
  final outerRadius = center * 0.95; // 外边缘
  final innerRadius = center * 0.31; // 内边缘（专辑封面区域）
  
  // 只绘制黑胶环形部分
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - center;
      final dy = y - center;
      final distance = math.sqrt(dx * dx + dy * dy);
      
      // 只在环形区域绘制
      if (distance >= innerRadius && distance <= outerRadius) {
        // 简单的黑色半透明
        final alpha = (0.7 * 255).round(); // 70% 不透明度
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, alpha));
      }
      // 其他区域保持完全透明（不设置任何像素）
    }
  }
  
  // 绘制几个同心圆纹路
  final ringRadii = [
    center * 0.85,
    center * 0.75,
    center * 0.65,
    center * 0.55,
    center * 0.45,
  ];
  
  for (final radius in ringRadii) {
    drawThinCircle(image, center.round(), center.round(), radius.round(), 
        img.ColorRgba8(0, 0, 0, 100)); // 更淡的纹路
  }
  
  // 绘制很小的中心点
  final centerDot = (size * 0.006).round();
  img.fillCircle(image, 
      x: center.round(), y: center.round(), radius: centerDot,
      color: img.ColorRgba8(0, 0, 0, 180));
  
  // 保存PNG文件
  final pngBytes = img.encodePng(image);
  final file = File(outputPath);
  await file.writeAsBytes(pngBytes);
  
  final fileSize = await file.length();
  print('  ✅ 透明PNG保存成功: $outputPath (${(fileSize / 1024).toStringAsFixed(1)} KB)');
}

/// 绘制细圆环
void drawThinCircle(img.Image image, int centerX, int centerY, int radius, img.Color color) {
  for (int angle = 0; angle < 360; angle += 2) { // 每2度绘制一个点，减少密度
    final radian = angle * math.pi / 180;
    final x = (centerX + radius * math.cos(radian)).round();
    final y = (centerY + radius * math.sin(radian)).round();
    
    if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
      image.setPixel(x, y, color);
    }
  }
}
