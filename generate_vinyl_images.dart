#!/usr/bin/env dart

/// 黑胶唱片PNG/WebP生成器
/// 使用 image 包生成多分辨率的PNG和WebP格式图片
/// 
/// 使用方式:
/// dart pub add image
/// dart run generate_vinyl_images.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  print('生成黑胶唱片PNG/WebP图片文件...');
  
  // 检查是否安装了image包
  try {
    // 尝试创建一个测试图片来验证包是否可用
    img.Image(width: 1, height: 1);
  } catch (e) {
    print('❌ 错误: 请先安装 image 包');
    print('运行: dart pub add image');
    return;
  }
  
  // 确保目录存在
  final directory = Directory('assets/images');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  
  // 生成多种分辨率的图片文件
  final sizes = [512, 1024, 1536]; // 1x, 2x, 3x
  
  for (final size in sizes) {
    final scale = size ~/ 512;
    print('\n正在生成 ${size}x$size (${scale}x) 分辨率的图片...');
    
    // 生成PNG
    await generateVinylPNG(size, 'assets/images/vinyl_ring_${scale}x.png');
    
    // 生成WebP
    await generateVinylWebP(size, 'assets/images/vinyl_ring_${scale}x.webp');
  }
  
  print('\n✅ 所有图片文件生成完成！');
  printUsageInstructions();
}

/// 生成PNG格式的黑胶唱片图片
Future<void> generateVinylPNG(int size, String outputPath) async {
  print('🎨 绘制 PNG: $size x $size');
  
  // 创建图片，并明确设置为透明背景
  final image = img.Image(width: size, height: size, numChannels: 4); // 确保有alpha通道
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0)); // 明确填充为完全透明
  
  final center = size / 2;
  
  // 绘制径向渐变背景
  await drawRadialGradient(image, center, center, center);
  
  // 绘制黑胶纹路 - 更密集、更细的同心圆，模拟真实黑胶
  final ringData = [
    // 外层纹路（更密集）
    {'r': size * 0.48, 'opacity': 15, 'width': 1}, // 更淡的纹路
    {'r': size * 0.46, 'opacity': 12, 'width': 1},
    {'r': size * 0.44, 'opacity': 15, 'width': 1},
    {'r': size * 0.42, 'opacity': 12, 'width': 1},
    {'r': size * 0.40, 'opacity': 15, 'width': 1},
    {'r': size * 0.38, 'opacity': 12, 'width': 1},
    {'r': size * 0.36, 'opacity': 15, 'width': 1},
    {'r': size * 0.34, 'opacity': 12, 'width': 1},
    // 中层纹路
    {'r': size * 0.32, 'opacity': 18, 'width': 1}, // 稍微明显一点但仍然很淡
    {'r': size * 0.30, 'opacity': 15, 'width': 1},
    {'r': size * 0.28, 'opacity': 18, 'width': 1},
    {'r': size * 0.26, 'opacity': 15, 'width': 1},
    {'r': size * 0.24, 'opacity': 18, 'width': 1},
    {'r': size * 0.22, 'opacity': 15, 'width': 1},
    {'r': size * 0.20, 'opacity': 18, 'width': 1},
    {'r': size * 0.18, 'opacity': 15, 'width': 1},
    {'r': size * 0.16, 'opacity': 18, 'width': 1},
  ];
  
  for (final ring in ringData) {
    final radius = ring['r'] as double;
    final opacity = ring['opacity'] as int;
    final strokeWidth = ring['width'] as int;
    
    drawCircleOutline(image, center.round(), center.round(), radius.round(), 
        img.ColorRgba8(255, 255, 255, opacity), strokeWidth); // 用白色来模拟反光纹路
  }
  
  // 绘制中心轴心 - 只在轴心很小的区域绘制，不影响专辑封面区域
  final centerRadius = (size * 0.012).round(); // 减小轴心半径，从0.019改为0.012
  img.fillCircle(image, 
      x: center.round(), y: center.round(), radius: centerRadius,
      color: img.ColorRgba8(0, 0, 0, 222)); // 0.87 * 255 = 222
  
  // 轴心边框
  drawCircleOutline(image, center.round(), center.round(), centerRadius,
      img.ColorRgba8(128, 128, 128, 77), (size * 0.002).round()); // 减小边框宽度
  
  // 保存PNG文件
  final pngBytes = img.encodePng(image);
  final file = File(outputPath);
  await file.writeAsBytes(pngBytes);
  
  final fileSize = await file.length();
  print('  ✅ PNG保存成功: $outputPath (${(fileSize / 1024).toStringAsFixed(1)} KB)');
}

/// 生成WebP格式的黑胶唱片图片
Future<void> generateVinylWebP(int size, String outputPath) async {
  print('🎨 绘制 WebP: $size x $size');
  
  // 创建图片，并明确设置为透明背景
  final image = img.Image(width: size, height: size, numChannels: 4); // 确保有alpha通道
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0)); // 明确填充为完全透明
  
  final center = size / 2;
  
  // 绘制径向渐变背景
  await drawRadialGradient(image, center, center, center);
  
  // 绘制黑胶纹路（与PNG相同的逻辑）
  final ringData = [
    // 外层纹路（更密集）
    {'r': size * 0.48, 'opacity': 15, 'width': 1}, // 更淡的纹路
    {'r': size * 0.46, 'opacity': 12, 'width': 1},
    {'r': size * 0.44, 'opacity': 15, 'width': 1},
    {'r': size * 0.42, 'opacity': 12, 'width': 1},
    {'r': size * 0.40, 'opacity': 15, 'width': 1},
    {'r': size * 0.38, 'opacity': 12, 'width': 1},
    {'r': size * 0.36, 'opacity': 15, 'width': 1},
    {'r': size * 0.34, 'opacity': 12, 'width': 1},
    // 中层纹路
    {'r': size * 0.32, 'opacity': 18, 'width': 1}, // 稍微明显一点但仍然很淡
    {'r': size * 0.30, 'opacity': 15, 'width': 1},
    {'r': size * 0.28, 'opacity': 18, 'width': 1},
    {'r': size * 0.26, 'opacity': 15, 'width': 1},
    {'r': size * 0.24, 'opacity': 18, 'width': 1},
    {'r': size * 0.22, 'opacity': 15, 'width': 1},
    {'r': size * 0.20, 'opacity': 18, 'width': 1},
    {'r': size * 0.18, 'opacity': 15, 'width': 1},
    {'r': size * 0.16, 'opacity': 18, 'width': 1},
  ];
  
  for (final ring in ringData) {
    final radius = ring['r'] as double;
    final opacity = ring['opacity'] as int;
    final strokeWidth = ring['width'] as int;
    
    drawCircleOutline(image, center.round(), center.round(), radius.round(), 
        img.ColorRgba8(255, 255, 255, opacity), strokeWidth); // 用白色来模拟反光纹路
  }
  
  // 绘制中心轴心 - 只在轴心很小的区域绘制，不影响专辑封面区域
  final centerRadius = (size * 0.012).round(); // 减小轴心半径
  img.fillCircle(image, 
      x: center.round(), y: center.round(), radius: centerRadius,
      color: img.ColorRgba8(0, 0, 0, 222));
  
  // 轴心边框
  drawCircleOutline(image, center.round(), center.round(), centerRadius,
      img.ColorRgba8(128, 128, 128, 77), (size * 0.002).round());
  
  // 保存WebP文件 (转换为PNG格式，因为encodeWebP可能不可用)
  final webpBytes = img.encodePng(image); // 暂时使用PNG编码
  final file = File(outputPath.replaceAll('.webp', '.png')); // 改为PNG扩展名
  await file.writeAsBytes(webpBytes);
  
  final fileSize = await file.length();
  print('  ⚠️  已保存为PNG格式: ${file.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)');
}

/// 绘制径向渐变
Future<void> drawRadialGradient(img.Image image, double centerX, double centerY, double maxRadius) async {
  final width = image.width;
  final height = image.height;
  
  // 定义黑胶唱片的内外半径
  final outerRadius = maxRadius; // 外边缘
  final innerRadius = maxRadius * 0.31; // 内边缘（中心透明区域，用于放置专辑封面）
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final dx = x - centerX;
      final dy = y - centerY;
      final distance = math.sqrt(dx * dx + dy * dy);
      
      // 只在黑胶唱片的环形区域内绘制（内圆和外圆之间）
      if (distance >= innerRadius && distance <= outerRadius) {
        // 真实黑胶的效果：整体都是深黑色，只有非常细微的径向变化
        // 避免强烈对比，保持一致的深色调
        final ratio = (distance - innerRadius) / (outerRadius - innerRadius);
        
        // 计算基础透明度 - 整体深色，变化很小
        int alpha;
        if (ratio <= 0.3) {
          // 内侧稍稍浅一点点
          alpha = (0.82 * 255).round(); // 82% 不透明
        } else if (ratio <= 0.7) {
          // 中间区域
          alpha = (0.85 * 255).round(); // 85% 不透明
        } else {
          // 外侧稍深
          alpha = (0.88 * 255).round(); // 88% 不透明
        }
        
        alpha = alpha.clamp(0, 255);
        image.setPixel(x, y, img.ColorRgba8(0, 0, 0, alpha));
      }
      // 其他区域（中心圆形和外部区域）保持透明
    }
  }
}

/// 绘制圆形轮廓
void drawCircleOutline(img.Image image, int centerX, int centerY, int radius, img.Color color, int strokeWidth) {
  // 只要在图片范围内就绘制圆环
  for (int angle = 0; angle < 360; angle++) {
    final radian = angle * math.pi / 180;
    
    for (int w = 0; w < strokeWidth; w++) {
      final currentRadius = radius + w - strokeWidth ~/ 2;
      if (currentRadius > 0) {
        final x = (centerX + currentRadius * math.cos(radian)).round();
        final y = (centerY + currentRadius * math.sin(radian)).round();
        
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

/// 打印使用说明
void printUsageInstructions() {
  print('''
🚀 使用说明:

1. 在 pubspec.yaml 中添加图片资源:
   flutter:
     assets:
       - assets/images/vinyl_ring_1x.png
       - assets/images/vinyl_ring_2x.png
       - assets/images/vinyl_ring_3x.png
       - assets/images/vinyl_ring_1x.webp
       - assets/images/vinyl_ring_2x.webp
       - assets/images/vinyl_ring_3x.webp

2. 在代码中使用:
   // 替换现有的SvgPicture.asset
   Image.asset(
     'assets/images/vinyl_ring_2x.png', // 或使用WebP
     width: 320,
     height: 320,
   )

3. 性能对比:
   ✅ PNG: 最佳兼容性，适中文件大小
   ✅ WebP: 最小文件大小，现代设备支持好
   🔄 根据需要选择合适的分辨率 (1x/2x/3x)

4. 动画性能:
   - PNG/WebP比SVG在旋转动画中性能更好
   - 建议使用RepaintBoundary包装旋转组件
   - 考虑预加载图片以避免首次显示延迟
''');
}
