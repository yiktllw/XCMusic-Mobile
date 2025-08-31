import 'package:flutter/material.dart';

/// 滚动文本组件
class ScrollingText extends StatefulWidget {
  /// 要显示的文本
  final String text;
  
  /// 文本样式
  final TextStyle? style;
  
  /// 文本对齐方式
  final TextAlign textAlign;
  
  /// 滚动速度（像素/秒）
  final double scrollSpeed;
  
  /// 滚动前的停顿时间（秒）
  final Duration pauseDuration;
  
  /// 滚动完成后的停顿时间（秒）
  final Duration endPauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.scrollSpeed = 35.0,
    this.pauseDuration = const Duration(seconds: 2),
    this.endPauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late ScrollController _scrollController;
  bool _isScrolling = false;
  bool _needsScrolling = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = AnimationController(
      duration: Duration.zero, // 会在_setupAnimation中重新设置
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScrolling();
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // 停止当前动画
      _controller.stop();
      _isScrolling = false;
      _isPaused = false;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkIfNeedsScrolling();
      });
    }
  }

  void _checkIfNeedsScrolling() {
    if (!mounted) return;
    
    // 停止之前的动画
    _controller.stop();
    _isScrolling = false;
    _isPaused = false;
    
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    
    final containerWidth = renderBox.size.width;
    final textWidth = textPainter.size.width;
    
    setState(() {
      _needsScrolling = textWidth > containerWidth;
    });
    
    if (_needsScrolling && !_isScrolling) {
      _startScrolling(textWidth, containerWidth);
    }
  }

  void _startScrolling(double textWidth, double containerWidth) {
    if (!mounted || _isScrolling) return;
    
    _isScrolling = true;
    // 计算滚动的总距离（原文本宽度 + 空白间距）
    final totalScrollDistance = textWidth + 80;
    
    _controller.duration = Duration(milliseconds: (totalScrollDistance / widget.scrollSpeed * 1000).round());
    
    _animation = Tween<double>(
      begin: 0.0,
      end: totalScrollDistance,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
    
    _animation.addListener(() {
      if (mounted && _scrollController.hasClients && !_isPaused) {
        _scrollController.jumpTo(_animation.value);
      }
    });
    
    // 监听动画状态变化
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 动画完成时，停顿一下再重新开始
        _pauseAndRestart();
      }
    });
    
    // 开始循环滚动
    _startContinuousScrolling();
  }

  Future<void> _pauseAndRestart() async {
    if (!mounted || !_needsScrolling) return;
    
    _isPaused = true;
    
    // 重置到开始位置
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    
    // 停顿一小会
    await Future.delayed(widget.endPauseDuration);
    
    if (!mounted || !_needsScrolling) return;
    
    _isPaused = false;
    _controller.reset();
    _controller.forward();
  }

  Future<void> _startContinuousScrolling() async {
    if (!mounted) return;
    
    // 初始等待
    await Future.delayed(widget.pauseDuration);
    if (!mounted || !_needsScrolling) return;
    
    // 开始第一次滚动
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.stop(); // 停止动画
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsScrolling) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: const [
            0.0,
            0.95,  // 在95%处开始渐变（约10px的渐变区域）
            1.0,   // 在100%处完全透明
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            // 原始文本
            Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
            ),
            // 空白间距
            SizedBox(width: 80),
            // 重复的文本内容，实现无限滚动效果
            Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
