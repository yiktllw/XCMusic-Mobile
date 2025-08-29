import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import '../models/playlist.dart';
import '../services/api_manager.dart';
import '../utils/global_config.dart';
import 'dart:math' as math;

/// 播放模式枚举
enum AudioPlayMode {
  listLoop,   // 列表循环
  singleLoop, // 单曲循环  
  shuffle,    // 随机播放
}

/// 后台音频服务处理器
class BackgroundAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentIndex = 0;
  
  /// 播放模式
  AudioPlayMode _playMode = AudioPlayMode.listLoop;
  
  BackgroundAudioHandler() {
    _init();
  }
  
  void _init() {
    // 监听播放状态变化
    _audioPlayer.playerStateStream.listen((state) {
      bool playing = state.playing;
      AudioProcessingState processingState;
      
      switch (state.processingState) {
        case ProcessingState.idle:
          processingState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          processingState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          processingState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          processingState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          processingState = AudioProcessingState.completed;
          _handleTrackCompleted();
          break;
      }
      
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
        speed: _audioPlayer.speed,
        queueIndex: _currentIndex,
      ));
    });
    
    // 监听播放位置变化
    _audioPlayer.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }
  
  @override
  Future<void> play() => _audioPlayer.play();
  
  @override
  Future<void> pause() => _audioPlayer.pause();
  
  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);
  
  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    
    if (_playMode == AudioPlayMode.shuffle) {
      // 随机播放
      final random = math.Random();
      int newIndex;
      do {
        newIndex = random.nextInt(queue.value.length);
      } while (newIndex == _currentIndex && queue.value.length > 1);
      _currentIndex = newIndex;
    } else {
      // 顺序播放
      if (_currentIndex < queue.value.length - 1) {
        _currentIndex++;
      } else if (_playMode == AudioPlayMode.listLoop) {
        _currentIndex = 0;
      } else {
        return; // 列表结束
      }
    }
    
    await _playCurrentTrack();
  }
  
  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    
    // 如果播放时间超过3秒，重新播放当前歌曲
    if (_audioPlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    
    if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_playMode == AudioPlayMode.listLoop) {
      _currentIndex = queue.value.length - 1;
    } else {
      return;
    }
    
    await _playCurrentTrack();
  }
  
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      _currentIndex = index;
      await _playCurrentTrack();
    }
  }
  
  /// 设置播放列表
  Future<void> setPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    final mediaItems = tracks.map((track) => MediaItem(
      id: track.id.toString(),
      album: track.album.name,
      title: track.name,
      artist: track.artists.map((a) => a.name).join(', '),
      duration: Duration(milliseconds: track.duration),
      artUri: Uri.parse(track.album.picUrl),
    )).toList();
    
    queue.add(mediaItems);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    
    if (tracks.isNotEmpty) {
      await _playCurrentTrack();
    }
  }
  
  /// 播放当前歌曲
  Future<void> _playCurrentTrack() async {
    if (queue.value.isEmpty || _currentIndex >= queue.value.length) return;
    
    final currentItem = queue.value[_currentIndex];
    mediaItem.add(currentItem);
    
    try {
      AppLogger.info('开始播放: ${currentItem.title}');
      
      // 获取播放链接
      final url = await _getSongUrl(currentItem.id);
      if (url != null) {
        await _audioPlayer.setUrl(url);
        await play();
      } else {
        AppLogger.error('无法获取播放链接: ${currentItem.title}');
        // 尝试播放下一首
        await skipToNext();
      }
    } catch (e) {
      AppLogger.error('播放失败: $e');
      // 尝试播放下一首
      await skipToNext();
    }
  }
  
  /// 获取歌曲播放链接
  Future<String?> _getSongUrl(String songId) async {
    try {
      final api = ApiManager();
      final cookie = GlobalConfig().getUserCookie() ?? "";
      
      final result = await api.api.songUrlV1(
        id: songId, 
        level: "standard", 
        cookie: cookie
      );
      
      Map<String, dynamic>? responseBody;
      if (result.containsKey('body')) {
        responseBody = result['body'] as Map<String, dynamic>?;
      } else {
        responseBody = result;
      }
      
      if (responseBody != null && responseBody['code'] == 200) {
        final urlData = responseBody['data'] as List?;
        if (urlData != null && urlData.isNotEmpty) {
          final firstItem = urlData[0] as Map<String, dynamic>;
          final url = firstItem['url'] as String?;
          return url;
        }
      }
      
      AppLogger.error('API返回的URL数据为空: $responseBody');
      return null;
    } catch (e) {
      AppLogger.error('获取播放链接失败: $e');
      return null;
    }
  }
  
  /// 处理歌曲播放完成
  void _handleTrackCompleted() {
    AppLogger.info('歌曲播放完成，当前播放模式: $_playMode');
    
    if (_playMode == AudioPlayMode.singleLoop) {
      // 单曲循环
      AppLogger.info('执行单曲循环');
      _playCurrentTrack();
    } else {
      // 播放下一首
      AppLogger.info('执行播放下一首');
      skipToNext();
    }
  }
  
  /// 设置播放模式
  void setPlayMode(AudioPlayMode mode) {
    _playMode = mode;
    AppLogger.info('播放模式已设置为: $_playMode');
  }
  
  /// 获取当前播放模式
  AudioPlayMode get playMode => _playMode;
  
  /// 获取当前播放位置
  Duration get position => _audioPlayer.position;
  
  /// 获取总时长
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  
  /// 是否正在播放
  bool get isPlaying => _audioPlayer.playing;
  
  /// 获取当前播放的歌曲
  MediaItem? get currentMediaItem => mediaItem.value;
  
  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    return super.stop();
  }
}
