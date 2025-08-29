import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import 'background_audio_service.dart';
import '../models/playlist.dart';

/// 音乐播放器管理服务
class MusicPlayerService extends ChangeNotifier {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  
  factory MusicPlayerService() => _instance;
  MusicPlayerService._internal();
  
  BackgroundAudioHandler? _audioHandler;
  bool _isInitialized = false;
  
  // 播放状态相关
  bool get isPlaying => _audioHandler?.playbackState.value.playing ?? false;
  bool get isPaused => !isPlaying && (_audioHandler?.playbackState.value.processingState != AudioProcessingState.idle);
  Duration get position => _audioHandler?.position ?? Duration.zero;
  Duration get duration => _audioHandler?.duration ?? Duration.zero;
  
  // 播放列表相关
  List<MediaItem> get playlist => _audioHandler?.queue.value ?? [];
  int get currentIndex => _audioHandler?.playbackState.value.queueIndex ?? 0;
  MediaItem? get currentTrack => _audioHandler?.currentMediaItem;
  
  // 播放模式
  AudioPlayMode get playMode => _audioHandler?.playMode ?? AudioPlayMode.listLoop;
  
  /// 初始化音频服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger.info('初始化音频服务...');
      
      _audioHandler = await AudioService.init(
        builder: () => BackgroundAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.xcmusic.audio',
          androidNotificationChannelName: 'XCMusic播放',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationChannelDescription: 'XCMusic音乐播放控制',
          androidStopForegroundOnPause: false,
        ),
      );
      
      // 监听播放状态变化
      _audioHandler?.playbackState.listen((_) {
        notifyListeners();
      });
      
      // 监听队列变化
      _audioHandler?.queue.listen((_) {
        notifyListeners();
      });
      
      // 监听媒体项变化
      _audioHandler?.mediaItem.listen((_) {
        notifyListeners();
      });
      
      _isInitialized = true;
      AppLogger.info('音频服务初始化完成');
    } catch (e) {
      AppLogger.error('音频服务初始化失败: $e');
      rethrow;
    }
  }
  
  /// 设置播放列表并开始播放
  Future<void> setPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    await _ensureInitialized();
    
    if (tracks.isEmpty) {
      AppLogger.warning('播放列表为空');
      return;
    }
    
    AppLogger.info('设置播放列表: ${tracks.length} 首歌曲，起始索引: $startIndex');
    
    try {
      await _audioHandler?.setPlaylist(tracks, startIndex: startIndex);
      notifyListeners();
    } catch (e) {
      AppLogger.error('设置播放列表失败: $e');
      rethrow;
    }
  }
  
  /// 播放
  Future<void> play() async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.play();
      AppLogger.info('开始播放');
    } catch (e) {
      AppLogger.error('播放失败: $e');
      rethrow;
    }
  }
  
  /// 暂停
  Future<void> pause() async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.pause();
      AppLogger.info('暂停播放');
    } catch (e) {
      AppLogger.error('暂停失败: $e');
      rethrow;
    }
  }
  
  /// 停止
  Future<void> stop() async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.stop();
      AppLogger.info('停止播放');
    } catch (e) {
      AppLogger.error('停止失败: $e');
      rethrow;
    }
  }
  
  /// 下一首
  Future<void> next() async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.skipToNext();
      AppLogger.info('切换到下一首');
    } catch (e) {
      AppLogger.error('切换下一首失败: $e');
      rethrow;
    }
  }
  
  /// 上一首
  Future<void> previous() async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.skipToPrevious();
      AppLogger.info('切换到上一首');
    } catch (e) {
      AppLogger.error('切换上一首失败: $e');
      rethrow;
    }
  }
  
  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.seek(position);
      AppLogger.info('跳转到位置: ${position.inSeconds}秒');
    } catch (e) {
      AppLogger.error('跳转失败: $e');
      rethrow;
    }
  }
  
  /// 播放指定索引的歌曲
  Future<void> playTrackAt(int index) async {
    await _ensureInitialized();
    
    try {
      await _audioHandler?.skipToQueueItem(index);
      AppLogger.info('播放索引为 $index 的歌曲');
    } catch (e) {
      AppLogger.error('播放指定歌曲失败: $e');
      rethrow;
    }
  }
  
  /// 设置播放模式
  void setPlayMode(AudioPlayMode mode) {
    _audioHandler?.setPlayMode(mode);
    AppLogger.info('播放模式设置为: $mode');
    notifyListeners();
  }
  
  /// 切换播放模式
  void togglePlayMode() {
    final currentMode = playMode;
    AudioPlayMode newMode;
    
    switch (currentMode) {
      case AudioPlayMode.listLoop:
        newMode = AudioPlayMode.singleLoop;
        break;
      case AudioPlayMode.singleLoop:
        newMode = AudioPlayMode.shuffle;
        break;
      case AudioPlayMode.shuffle:
        newMode = AudioPlayMode.listLoop;
        break;
    }
    
    setPlayMode(newMode);
  }
  
  /// 添加歌曲到播放列表
  Future<void> addTrack(Track track) async {
    await _ensureInitialized();
    
    // 这里需要实现添加单个歌曲的逻辑
    // 暂时通过重新设置播放列表来实现
    final currentTracks = await _getTracksFromQueue();
    currentTracks.add(track);
    
    final currentIndex = this.currentIndex;
    await setPlaylist(currentTracks, currentIndex);
  }
  
  /// 从播放列表移除歌曲
  Future<void> removeTrack(int index) async {
    await _ensureInitialized();
    
    final currentTracks = await _getTracksFromQueue();
    if (index >= 0 && index < currentTracks.length) {
      currentTracks.removeAt(index);
      
      int newCurrentIndex = currentIndex;
      if (index < currentIndex) {
        newCurrentIndex--;
      } else if (index == currentIndex && currentTracks.isNotEmpty) {
        newCurrentIndex = newCurrentIndex.clamp(0, currentTracks.length - 1);
      }
      
      if (currentTracks.isNotEmpty) {
        await setPlaylist(currentTracks, newCurrentIndex);
      } else {
        await stop();
      }
    }
  }
  
  /// 清空播放列表
  Future<void> clearPlaylist() async {
    await _ensureInitialized();
    await stop();
    // 清空队列的逻辑需要在AudioHandler中实现
  }
  
  /// 从MediaItem队列转换回Track列表（简化实现）
  Future<List<Track>> _getTracksFromQueue() async {
    // 这是一个简化实现，实际应用中需要维护完整的Track信息
    // 或者在AudioHandler中保存原始Track数据
    return [];
  }
  
  /// 确保服务已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  /// 释放资源
  @override
  void dispose() {
    _audioHandler?.stop();
    super.dispose();
  }
}
