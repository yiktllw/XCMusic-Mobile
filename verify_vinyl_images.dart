#!/usr/bin/env dart

/// 验证生成的黑胶图片是否为透明背景的圆形
/// 检查图片的透明度和圆形边界

// ignore_for_file: dangling_library_doc_comments, avoid_print

import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('🔍 验证黑胶图片透明度和形状...\n');
  
  final testFiles = [
    'assets/images/vinyl_ring_1x.png',
    'assets/images/vinyl_ring_2x.png', 
    'assets/images/vinyl_ring_3x.png',
  ];
  
  for (final filePath in testFiles) {
    await verifyImage(filePath);
  }
}

Future<void> verifyImage(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    print('❌ 文件不存在: $filePath');
    return;
  }
  
  final bytes = await file.readAsBytes();
  final image = img.decodePng(bytes);
  
  if (image == null) {
    print('❌ 无法解码PNG: $filePath');
    return;
  }
  
  print('📊 验证 $filePath:');
  print('   尺寸: ${image.width}x${image.height}');
  
  // 检查四个角是否透明
  final corners = [
    [0, 0], // 左上角
    [image.width - 1, 0], // 右上角
    [0, image.height - 1], // 左下角
    [image.width - 1, image.height - 1], // 右下角
  ];
  
  bool cornersTransparent = true;
  for (final corner in corners) {
    final pixel = image.getPixel(corner[0], corner[1]);
    final alpha = pixel.a; // 直接访问alpha通道
    if (alpha != 0) {
      cornersTransparent = false;
      break;
    }
  }
  
  // 检查中心是否透明（专辑封面区域）
  final centerX = image.width ~/ 2;
  final centerY = image.height ~/ 2;
  final centerPixel = image.getPixel(centerX, centerY);
  final centerAlpha = centerPixel.a;
  
  // 检查黑胶边缘是否有内容
  final edgeRadius = (image.width * 0.45).round();
  final edgeX = centerX + edgeRadius;
  final edgeY = centerY;
  final edgePixel = image.getPixel(edgeX, edgeY);
  final edgeAlpha = edgePixel.a;
  
  // 统计透明像素数量
  int transparentPixels = 0;
  int totalPixels = image.width * image.height;
  
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final alpha = pixel.a; // 直接访问alpha通道
      if (alpha == 0) {
        transparentPixels++;
      }
    }
  }
  
  final transparentPercentage = (transparentPixels / totalPixels * 100);
  
  print('   四角透明度: ${cornersTransparent ? "✅ 透明" : "❌ 不透明"}');
  print('   中心透明度: ${centerAlpha == 0 ? "✅ 透明" : "❌ 不透明 (alpha: $centerAlpha)"}');
  print('   边缘内容: ${edgeAlpha > 0 ? "✅ 有内容" : "❌ 无内容 (alpha: $edgeAlpha)"}');
  print('   透明像素: ${transparentPercentage.toStringAsFixed(1)}%');
  
  // 判断整体验证结果
  final isValid = cornersTransparent && 
                  centerAlpha == 0 && 
                  edgeAlpha > 0 && 
                  transparentPercentage > 40; // 至少40%透明
  
  print('   验证结果: ${isValid ? "✅ 合格" : "❌ 不合格"}\n');
}
