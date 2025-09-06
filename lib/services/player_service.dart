import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import '../models/playlist.dart';
import '../services/api_manager.dart';
import '../utils/global_config.dart';
import 'sleep_timer_service.dart';
import 'navigation_service.dart';
import '../widgets/night_mode_ask_dialog.dart';

/// 播放模式
enum PlayMode {
  /// 列表循环
  listLoop,
  /// 单曲循环
  singleLoop,
  /// 随机播放
  shuffle,
}

/// 播放器状态
enum PlaybackState {
  /// 停止
  stopped,
  /// 播放中
  playing,
  /// 暂停
  paused,
  /// 缓冲中
  buffering,
}

/// 播放器服务
class PlayerService extends ChangeNotifier {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;
  PlayerService._internal() {
    _initializePlayer();
    _loadSettings();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _mediaSessionUpdateTimer;
  
  // 播放状态
  PlaybackState _playerState = PlaybackState.stopped;
  PlayMode _playMode = PlayMode.listLoop;
  
  // 播放列表
  List<Track> _playlist = [];
  int _currentIndex = -1;
  
  // 播放进度
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // 用于跟踪MediaSession中的歌曲变化
  String? _lastUpdateTrackId;
  
  // 上次保存状态的时间，避免频繁保存
  DateTime? _lastSaveTime;
  
  // 定时关闭相关状态
  bool _shouldStopAfterCurrentTrack = false;
  
  // 用于跟踪用户手动播放意图
  bool _isUserInitiatedPlay = false;

  /// 初始化播放器
  void _initializePlayer() {
    // 初始化音频上下文
    _updateAudioContext();
    
    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) async {
      final oldState = _playerState;
      switch (state) {
        case PlayerState.playing:
          _playerState = PlaybackState.playing;
          break;
        case PlayerState.paused:
          _playerState = PlaybackState.paused;
          break;
        case PlayerState.stopped:
          _playerState = PlaybackState.stopped;
          break;
        case PlayerState.completed:
          _playerState = PlaybackState.stopped;
          break;
        case PlayerState.disposed:
          _playerState = PlaybackState.stopped;
          break;
      }
      
      // 只有当播放状态真正改变时才强制更新 MediaSession
      if (oldState != _playerState) {
        await _forceUpdateMediaSession();
        
        // 检查夜间询问：当开始播放且是用户发起的播放时
        if (_playerState == PlaybackState.playing && _isUserInitiatedPlay) {
          AppLogger.info('🌙 用户发起的播放已开始，检查夜间询问条件');
          _checkAndShowNightModeAsk();
          _isUserInitiatedPlay = false; // 重置标志
        }
        
        // 启动或停止定时器
        if (_playerState == PlaybackState.playing) {
          _startMediaSessionUpdateTimer();
        } else {
          _stopMediaSessionUpdateTimer();
        }
      }
      
      notifyListeners();
    });

    // 监听播放完成（只在这里监听一次）
    _audioPlayer.onPlayerComplete.listen((_) {
      // 音频播放完成时自动跳到下一首
      _onTrackCompleted();
    });

    // 监听播放时长
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    // 监听播放进度
    _audioPlayer.onPositionChanged.listen((position) {
      // 确保播放位置不超过总时长
      _position = Duration(
        milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds)
      );
      notifyListeners();
      
      // 每10秒保存一次状态，避免太频繁
      if (_position.inSeconds > 0 && _position.inSeconds % 10 == 0) {
        _saveState().catchError((e) {
          AppLogger.error('保存播放状态失败', e);
        });
      }
    });
    
    // 启动 MediaSession 更新定时器（每秒更新一次播放进度）
    _startMediaSessionUpdateTimer();
  }

  /// 启动 MediaSession 更新定时器
  void _startMediaSessionUpdateTimer() {
    _mediaSessionUpdateTimer?.cancel();
    _mediaSessionUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (currentTrack != null && isPlaying) {
        try {
          // 获取实时播放位置
          final currentPosition = await _audioPlayer.getCurrentPosition();
          final realTimePosition = currentPosition ?? Duration.zero;
          
          // 检查播放器实际状态
          final actualPlayerState = _audioPlayer.state;
          
          // 如果说在播放但实际不是，说明播放有问题
          if (actualPlayerState != PlayerState.playing) {
            // 重置状态，停止虚假的playing报告
            _playerState = PlaybackState.stopped;
            notifyListeners();
            await _forceUpdateMediaSession();
            return;
          }
          
          // 更新缓存的位置
          _position = realTimePosition;
          
          // 检查歌曲是否发生变化
          final currentTrackId = currentTrack!.id.toString();
          final trackChanged = _lastUpdateTrackId != currentTrackId;
          
          if (trackChanged) {
            // 歌曲变化时立即更新完整信息
            AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
            AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
            _lastUpdateTrackId = currentTrackId;
          }
          
          // 只有在真正播放时才报告playing状态
          final isReallyPlaying = actualPlayerState == PlayerState.playing && realTimePosition >= Duration.zero;
          AudioPlayerHandler.instance.updatePlaybackState(_playerState, isReallyPlaying, realTimePosition);
          
          // 每10秒强制更新一次完整的MediaSession信息
          if (realTimePosition.inSeconds % 10 == 0 && !trackChanged) {
            AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
          }
        } catch (e) {
          AppLogger.warning('获取播放位置失败: $e');
        }
      }
    });
  }

  /// 停止 MediaSession 更新定时器
  void _stopMediaSessionUpdateTimer() {
    _mediaSessionUpdateTimer?.cancel();
    _mediaSessionUpdateTimer = null;
    _lastUpdateTrackId = null; // 重置跟踪变量
  }

  /// 更新音频上下文配置
  Future<void> _updateAudioContext() async {
    // 读取设置
    final prefs = await SharedPreferences.getInstance();
    final allowInterruption = prefs.getBool('allow_interruption') ?? true;
    
    AppLogger.info('🔊 开始更新音频上下文 - 允许与其他应用同时播放: $allowInterruption');
    
    // 根据设置选择合适的音频焦点策略
    final audioFocus = allowInterruption 
        ? AndroidAudioFocus.none                   // 不请求音频焦点，允许同时播放
        : AndroidAudioFocus.gain;                  // 请求独占音频焦点
    
    AppLogger.info('🔊 选择的音频焦点策略: ${audioFocus.toString()}');
    
    // 配置音频播放器模式为媒体
    _audioPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: allowInterruption 
            ? {AVAudioSessionOptions.mixWithOthers}  // iOS允许混音
            : {},
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: audioFocus,
      ),
    ));
    
    AppLogger.info('🔊 音频上下文已更新: allowInterruption=$allowInterruption, audioFocus=$audioFocus');
  }

  /// 公开方法：更新音频焦点设置
  Future<void> updateAudioFocusSettings() async {
    await _updateAudioContext();
  }

  /// 公开方法：设置音量
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      AppLogger.info('🔊 音量已设置为: ${(volume * 100).round()}%');
    } catch (e) {
      AppLogger.error('设置音量失败: $e');
    }
  }

  /// 加载用户设置
  Future<void> _loadSettings() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // 加载音量设置
        final volume = prefs.getDouble('volume') ?? 1.0;
        await _audioPlayer.setVolume(volume);
        
        AppLogger.config('已加载用户设置: 音量=$volume');
        return; // 成功加载，退出重试循环
      } catch (e) {
        retryCount++;
        AppLogger.error('加载用户设置失败 (尝试 $retryCount/$maxRetries): $e');

        if (retryCount < maxRetries) {
          // 等待一段时间后重试
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        } else {
          AppLogger.warning('多次尝试后仍无法加载用户设置，将使用默认设置');
          // 使用默认设置
          await _audioPlayer.setVolume(1.0);
        }
      }
    }
  }

  // Getters
  PlaybackState get playerState => _playerState;
  PlayMode get playMode => _playMode;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Track? get currentTrack => _currentIndex >= 0 && _currentIndex < _playlist.length 
      ? _playlist[_currentIndex] 
      : null;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _playerState == PlaybackState.playing;
  bool get isPaused => _playerState == PlaybackState.paused;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  bool get shouldStopAfterCurrentTrack => _shouldStopAfterCurrentTrack;

  /// 设置是否在当前歌曲播放完成后停止
  void setShouldStopAfterCurrentTrack(bool shouldStop) {
    _shouldStopAfterCurrentTrack = shouldStop;
    AppLogger.info('设置播放完成后停止状态: $shouldStop');
  }

  /// 重写 notifyListeners 以自动更新 MediaSession
  @override
  void notifyListeners() {
    super.notifyListeners();
    // 只在必要时更新媒体会话，避免过于频繁的更新
    _updateMediaSessionIfNeeded();
  }

  /// 仅在需要时更新媒体会话（避免频繁更新）
  void _updateMediaSessionIfNeeded() {
    // 只在播放状态改变或歌曲改变时才更新完整的 MediaSession
    // 播放进度的更新由单独的定时器处理
  }

  /// 强制更新媒体会话（用于状态和歌曲变化）
  Future<void> _forceUpdateMediaSession() async {
    try {
      if (currentTrack != null) {
        // 获取实时播放位置
        _audioPlayer.getCurrentPosition().then((currentPosition) {
          final realTimePosition = currentPosition ?? _position;
          
          // 更新 AudioService 的媒体信息和播放状态
          AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
          AudioPlayerHandler.instance.updatePlaybackState(_playerState, isPlaying, realTimePosition);
          
          // 更新缓存的位置
          _position = realTimePosition;
        }).catchError((e) async {
          // 如果获取位置失败，尝试再次获取或使用缓存的位置
          Duration fallbackPosition = _position;
          try {
            fallbackPosition = await _audioPlayer.getCurrentPosition() ?? _position;
          } catch (e2) {
            // 静默处理
          }
          AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
          AudioPlayerHandler.instance.updatePlaybackState(_playerState, isPlaying, fallbackPosition);
        });
      } else {
        // 清除媒体会话
        AudioPlayerHandler.instance.updatePlaybackState(PlaybackState.stopped, false, Duration.zero);
      }
    } catch (e) {
      // 如果AudioService未初始化，延迟1秒后重试
      Future.delayed(const Duration(seconds: 1), () {
        if (currentTrack != null) {
          _forceUpdateMediaSession();
        }
      });
    }
  }

  /// 初始化播放器
  Future<void> initialize() async {
    try {
      // 在后台加载保存的播放状态，不阻塞初始化
      _loadSavedStateInBackground();
      
      // 延迟同步MediaSession状态，确保AudioService完全初始化
      Future.delayed(const Duration(seconds: 2), () async {
        await _syncMediaSessionState();
      });
      
      // 初始化完成
    } catch (e) {
      AppLogger.error('播放器初始化失败: $e');
    }
  }
  
  /// 同步MediaSession状态
  Future<void> _syncMediaSessionState() async {
    try {
      if (currentTrack != null) {
        // MediaSession状态同步
        AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
        AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
        
        // 获取实时位置进行状态同步
        try {
          final realTimePosition = await _audioPlayer.getCurrentPosition() ?? _position;
          AudioPlayerHandler.instance.updatePlaybackState(_playerState, isPlaying, realTimePosition);
        } catch (e) {
          // 获取失败则使用缓存位置
          AppLogger.warning('同步状态时获取位置失败，使用缓存位置: $e');
          AudioPlayerHandler.instance.updatePlaybackState(_playerState, isPlaying, _position);
        }
      } else {
        // MediaSession状态同步：无当前歌曲
        // 确保空状态也正确同步
        AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
        AudioPlayerHandler.instance.updatePlaybackState(PlaybackState.stopped, false, Duration.zero);
      }
    } catch (e) {
      AppLogger.warning('MediaSession状态同步失败: $e');
    }
  }
  
  /// 在后台加载保存的状态，不阻塞应用启动
  void _loadSavedStateInBackground() {
    _loadSavedState().catchError((e) {
      AppLogger.error('后台加载播放状态失败: $e');
    });
  }

  /// 获取存储文件路径
  Future<String> _getStorageFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/player_state.json';
  }

  /// 保存播放状态（避免频繁保存）
  Future<void> _saveState() async {
    try {
      // 检查是否距离上次保存已经过了至少2秒
      final now = DateTime.now();
      if (_lastSaveTime != null && 
          now.difference(_lastSaveTime!).inSeconds < 2) {
        return; // 跳过保存，避免过于频繁
      }
      
      final filePath = await _getStorageFilePath();
      final file = File(filePath);
      
      final stateData = {
        'currentIndex': _currentIndex,
        'duration': _duration.inMilliseconds,
        'playMode': _playMode.index,
        'playerState': _playerState.index,
        'playlist': _playlist.map((track) => {
          'id': track.id,
          'name': track.name,
          'artists': track.artists.map((artist) => {
            'id': artist.id,
            'name': artist.name,
          }).toList(),
          'album': {
            'id': track.album.id,
            'name': track.album.name,
            'picUrl': track.album.picUrl,
          },
          'duration': track.duration,
          'popularity': track.popularity,
          'fee': track.fee,
        }).toList(),
      };
      
      await file.writeAsString(jsonEncode(stateData));
      _lastSaveTime = now;
      // 状态保存完成
    } catch (e) {
      AppLogger.error('保存播放状态失败', e);
    }
  }

  /// 加载保存的播放状态
  Future<void> _loadSavedState() async {
    try {
      final filePath = await _getStorageFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        // 没有找到保存的播放状态文件
        return;
      }
      
      final content = await file.readAsString();
      final stateData = jsonDecode(content) as Map<String, dynamic>;
      
      // 恢复播放列表
      final playlistData = stateData['playlist'] as List?;
      if (playlistData != null) {
        _playlist = playlistData.map<Track>((trackData) {
          final track = trackData as Map<String, dynamic>;
          final artistsData = track['artists'] as List;
          final albumData = track['album'] as Map<String, dynamic>;
          
          return Track(
            id: track['id'] as int,
            name: track['name'] as String,
            artists: artistsData.map<Artist>((artistData) {
              final artist = artistData as Map<String, dynamic>;
              return Artist(
                id: artist['id'] as int,
                name: artist['name'] as String,
              );
            }).toList(),
            album: Album(
              id: albumData['id'] as int,
              name: albumData['name'] as String,
              picUrl: albumData['picUrl'] as String,
            ),
            duration: track['duration'] as int,
            popularity: (track['popularity'] as num).toDouble(),
            fee: track['fee'] as int,
          );
        }).toList();
      }
      
      // 恢复其他状态
      _currentIndex = stateData['currentIndex'] as int? ?? -1;
      _duration = Duration(milliseconds: stateData['duration'] as int? ?? 0);
      
      final playModeIndex = stateData['playMode'] as int? ?? 0;
      _playMode = PlayMode.values[playModeIndex.clamp(0, PlayMode.values.length - 1)];
      
      final playerStateIndex = stateData['playerState'] as int? ?? 0;
      _playerState = PlaybackState.values[playerStateIndex.clamp(0, PlaybackState.values.length - 1)];
      
      // 通知监听器更新UI
      notifyListeners();

      // 播放状态已恢复

      // 如果有当前歌曲，恢复播放状态
      if (_playlist.isNotEmpty && _currentIndex >= 0 && _currentIndex < _playlist.length) {
        await _restorePlaybackState();
      }
    } catch (e) {
      AppLogger.error('加载保存的播放状态失败: $e');
    }
  }

  /// 恢复播放状态，重新获取播放链接并设置进度
  Future<void> _restorePlaybackState() async {
    if (currentTrack == null) return;
    
    try {
      // 正在恢复播放状态...

      // 读取用户设置（只关心自动播放）
      bool shouldAutoPlay = false;
      
      try {
        final prefs = await SharedPreferences.getInstance().timeout(Duration(seconds: 3));
        shouldAutoPlay = prefs.getBool('auto_play') ?? false;
      } catch (e) {
        AppLogger.warning('读取用户设置失败，使用默认值: $e');
        shouldAutoPlay = false;
      }

      AppLogger.info('用户设置: shouldAutoPlay=$shouldAutoPlay');

      // 重新获取播放链接（设置超时）
      try {
        final url = await _getSongUrl(currentTrack!.id.toString()).timeout(Duration(seconds: 8));
        if (url != null) {
          if (shouldAutoPlay && _playerState == PlaybackState.playing) {
            // 如果用户开启了自动播放且之前是播放状态，则开始播放
            await _audioPlayer.play(UrlSource(url));
          } else {
            // 否则只设置音频源但不播放
            await _audioPlayer.setSource(UrlSource(url));
            _playerState = PlaybackState.paused;
            notifyListeners();
            // 播放状态已恢复为暂停
          }
        } else {
          AppLogger.warning('无法获取播放链接，跳过播放状态恢复');
          _playerState = PlaybackState.stopped;
          notifyListeners();
        }
      } catch (e) {
        AppLogger.warning('获取播放链接超时或失败，跳过播放状态恢复: $e');
        _playerState = PlaybackState.stopped;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('恢复播放状态失败: $e');
      _playerState = PlaybackState.stopped;
      notifyListeners();
    }
  }

  /// 播放当前歌曲
  Future<void> _playCurrentTrack() async {
    if (currentTrack == null) return;

    try {
      _playerState = PlaybackState.buffering;
      notifyListeners();

      // 确保音频上下文在播放前正确设置
      await _updateAudioContext();

      // 立即更新MediaSession歌曲信息（在开始播放前）
      AudioPlayerHandler.instance.updateCurrentMediaItem(currentTrack!);
      AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
      AudioPlayerHandler.instance.updatePlaybackState(_playerState, false, Duration.zero);
      // 立即更新歌曲信息

      // 获取播放链接
      final url = await _getSongUrl(currentTrack!.id.toString());
      if (url != null) {
        // 重置进度并正常播放
        _position = Duration.zero;
        await _audioPlayer.play(UrlSource(url));
        
        // 等待播放器状态稳定并验证播放是否成功
        await Future.delayed(const Duration(milliseconds: 500));
        
        final actualState = _audioPlayer.state;
        if (actualState == PlayerState.playing) {
          _playerState = PlaybackState.playing;
        } else {
          // 如果没有正常播放，尝试重启一次
          await _audioPlayer.stop();
          await Future.delayed(const Duration(milliseconds: 300));
          await _audioPlayer.play(UrlSource(url));
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (_audioPlayer.state == PlayerState.playing) {
            _playerState = PlaybackState.playing;
          } else {
            _playerState = PlaybackState.stopped;
          }
        }
        
        // 确保状态同步
        await _forceUpdateMediaSession();
      } else {
        // 如果获取不到播放链接，跳到下一首
        await next();
      }
    } catch (e) {
      AppLogger.error('播放失败: $e');
      _playerState = PlaybackState.stopped;
      notifyListeners();
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
      
      // 检查不同的响应结构
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

  /// 设置播放列表并开始播放
  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    // 标记这是用户发起的播放
    _isUserInitiatedPlay = true;
    AppLogger.info('🌙 用户选择播放列表，设置夜间询问检查标志');
    
    _playlist = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    
    // 更新AudioService队列
    AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
    
    await _playCurrentTrack();
    await _saveState(); // 保存状态
  }

  /// 播放/暂停切换
  Future<void> playPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// 播放
  Future<void> play() async {
    // 播放方法被调用
    
    // 标记这是用户发起的播放
    _isUserInitiatedPlay = true;
    AppLogger.info('🌙 用户手动播放，设置夜间询问检查标志');
    
    // 确保音频上下文在每次播放时都正确设置
    await _updateAudioContext();
    
    if (currentTrack != null) {
      if (_playerState == PlaybackState.stopped) {
        // 如果是停止状态，重新开始播放当前歌曲
        AppLogger.info('🎵 开始播放: ${currentTrack!.name}');
        await _playCurrentTrack();
      } else {
        // 如果是暂停状态，恢复播放
        AppLogger.info('🎵 恢复播放: ${currentTrack!.name}');
        await _audioPlayer.resume();
        await _forceUpdateMediaSession(); // 确保MediaSession状态同步
      }
    } else {
      AppLogger.warning('🎵 无当前歌曲，无法播放');
    }
  }

  /// 检查并显示夜间询问对话框
  void _checkAndShowNightModeAsk() {
    try {
      final sleepTimerService = SleepTimerService();
      
      // 检查是否应该询问设置定时关闭
      if (sleepTimerService.shouldAskForSleepTimer()) {
        AppLogger.info('🌙 检测到夜间手动播放，准备显示询问对话框');
        
        // 使用NavigationService显示对话框
        Future.delayed(const Duration(milliseconds: 500), () {
          final navigationService = NavigationService();
          navigationService.showDialogGlobal(
            builder: (context) => const NightModeAskDialog(),
            barrierDismissible: false,
          );
        });
      }
    } catch (e) {
      AppLogger.error('检查夜间询问时出错', e);
    }
  }

  /// 设置播放列表并开始播放（兼容旧接口）
  Future<void> setPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    await playPlaylist(tracks, startIndex: startIndex);
  }

  /// 暂停
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _position = Duration.zero;
  }

  /// 下一首
  Future<void> next({bool userInitiated = false}) async {
    AppLogger.info('next() 调用开始，当前播放模式: $_playMode, 当前索引: $_currentIndex, 播放列表长度: ${_playlist.length}');
    
    // 如果是用户发起的操作，设置标志
    if (userInitiated) {
      _isUserInitiatedPlay = true;
    }
    
    if (_playMode == PlayMode.shuffle) {
      // 随机播放
      if (_playlist.length > 1) {
        final random = math.Random();
        int newIndex;
        do {
          newIndex = random.nextInt(_playlist.length);
        } while (newIndex == _currentIndex && _playlist.length > 1);
        AppLogger.info('随机播放：从索引 $_currentIndex 切换到 $newIndex');
        _currentIndex = newIndex;
      }
    } else {
      // 顺序播放
      final oldIndex = _currentIndex;
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        AppLogger.info('顺序播放：从索引 $oldIndex 递增到 $_currentIndex');
      } else if (_playMode == PlayMode.listLoop) {
        _currentIndex = 0;
        AppLogger.info('列表循环：从索引 $oldIndex 重置到 0');
      } else {
        AppLogger.info('列表结束，不切换歌曲');
        return; // 列表结束
      }
    }
    await _playCurrentTrack();
    // 异步保存状态，不阻塞UI
    _saveState().catchError((e) {
      AppLogger.error('保存播放状态失败', e);
    });
  }

  /// 上一首
  Future<void> previous({bool userInitiated = false}) async {
    // 如果是用户发起的操作，设置标志
    if (userInitiated) {
      _isUserInitiatedPlay = true;
    }
    
    if (_position.inSeconds > 3) {
      // 如果播放时间超过3秒，重新播放当前歌曲
      await seek(Duration.zero);
    } else {
      // 否则播放上一首
      if (_currentIndex > 0) {
        _currentIndex--;
      } else if (_playMode == PlayMode.listLoop) {
        _currentIndex = _playlist.length - 1;
      } else {
        return;
      }
      await _playCurrentTrack();
      // 异步保存状态，不阻塞UI
      _saveState().catchError((e) {
        AppLogger.error('保存播放状态失败', e);
      });
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    // 确保跳转位置在有效范围内
    final safePosition = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds)
    );
    
    // 立即更新UI显示的位置
    _position = safePosition;
    notifyListeners();
    
    // 执行实际的跳转
    await _audioPlayer.seek(safePosition);
  }

  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
    // 异步保存状态，不阻塞UI
    _saveState().catchError((e) {
      AppLogger.error('保存播放模式失败', e);
    });
  }

  /// 歌曲播放完成回调
  void _onTrackCompleted() {
    AppLogger.info('歌曲播放完成，当前播放模式: $_playMode, 当前索引: $_currentIndex');
    
    // 检查是否需要在当前歌曲播放完成后停止
    if (_shouldStopAfterCurrentTrack) {
      AppLogger.info('检测到定时关闭标志，停止播放');
      _shouldStopAfterCurrentTrack = false; // 重置标志
      stop().catchError((e) {
        AppLogger.error('定时关闭停止播放失败', e);
      });
      return;
    }
    
    if (_playMode == PlayMode.singleLoop) {
      // 单曲循环 - 异步调用不阻塞
      AppLogger.info('执行单曲循环，保持索引: $_currentIndex');
      _playCurrentTrack().catchError((e) {
        AppLogger.error('单曲循环播放失败', e);
      });
    } else {
      // 播放下一首 - 异步调用不阻塞
      AppLogger.info('执行播放下一首，当前索引: $_currentIndex');
      next().catchError((e) {
        AppLogger.error('播放下一首失败', e);
      });
    }
  }

  /// 快速实现一个解决方案：简单地调用next()和previous()方法来处理playTrackAt
  Future<void> playTrackAt(int index, {bool userInitiated = true}) async {
    if (index >= 0 && index < _playlist.length) {
      // 只有在用户发起的情况下才标记
      if (userInitiated) {
        _isUserInitiatedPlay = true;
      }
      
      _currentIndex = index;
      
      // 更新AudioService队列当前索引
      AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
      
      await _playCurrentTrack();
    }
  }

  /// 从播放列表移除歌曲
  Future<void> removeFromPlaylist(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        if (_currentIndex >= _playlist.length) {
          _currentIndex = _playlist.length - 1;
        }
        if (_playlist.isNotEmpty) {
          _playCurrentTrack();
        } else {
          stop();
        }
      }
      
      // 更新AudioService队列
      AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
      
      notifyListeners();
    }
  }

  /// 清空播放列表
  Future<void> clearPlaylist() async {
    await stop();
    _playlist.clear();
    _currentIndex = -1;
    
    // 更新AudioService队列
    AudioPlayerHandler.instance.updatePlaylist(_playlist, _currentIndex);
    
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _stopMediaSessionUpdateTimer();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// AudioService 后台音频处理器
class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static AudioPlayerHandler? _instance;
  static AudioPlayerHandler get instance {
    _instance ??= AudioPlayerHandler._internal();
    return _instance!;
  }
  
  AudioPlayerHandler._internal() {
    _init();
    
    // 确保MediaBrowserService能够正确连接
    Future.delayed(const Duration(milliseconds: 500), () {
      debugPrint('🎵 AudioService延迟初始化完成，准备接收连接');
      // 强制触发一次状态更新，确保连接正常
      _forceInitialUpdate();
    });
  }
  
  void _forceInitialUpdate() {
    try {
      // 强制更新初始状态
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      
      // 设置空的队列
      queue.add(<MediaItem>[]);
      
      debugPrint('🎵 AudioService强制初始更新完成');
    } catch (e) {
      debugPrint('🎵 AudioService初始更新失败: $e');
    }
  }
  
  void _init() {
    // 初始化播放状态
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
        MediaAction.skipToQueueItem,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    
    // 初始化空的队列
    queue.add(<MediaItem>[]);
    
    debugPrint('🎵 AudioPlayerHandler初始化完成');
  }
  
  // MediaBrowserService 支持方法
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    debugPrint('🎵 AudioService收到获取子项请求: $parentMediaId');
    
    // 立即返回结果，不要有任何延迟
    try {
      switch (parentMediaId) {
        case AudioService.browsableRootId:
          // 返回根目录的项目，提供更多选项
          final rootItems = [
            const MediaItem(
              id: 'playlist',
              title: '当前播放列表',
              playable: false,
              extras: {
                'isFolder': true,
                'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
                'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
              },
            ),
            const MediaItem(
              id: 'recent',
              title: '最近播放',
              playable: false,
              extras: {
                'isFolder': true,
                'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
                'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
              },
            ),
          ];
          debugPrint('🎵 AudioService返回根目录${rootItems.length}个项目');
          return rootItems;
        case 'playlist':
          // 返回播放列表中的歌曲
          final playerService = PlayerService();
          final mediaItems = playerService.playlist.map((track) => MediaItem(
            id: track.id.toString(),
            album: track.album.name,
            title: track.name,
            artist: track.artists.map((a) => a.name).join(', '),
            duration: Duration(milliseconds: track.duration),
            artUri: track.album.picUrl.isNotEmpty 
                ? Uri.parse('${track.album.picUrl}?param=300y300') 
                : null,
            playable: true,
            extras: {
              'trackId': track.id.toString(),
              'isPlayable': true,
              'source': 'playlist',
            },
          )).toList();
          
          debugPrint('🎵 AudioService返回播放列表${mediaItems.length}个媒体项目');
          return mediaItems;
        case 'recent':
          // 返回空的最近播放列表（可以后续实现）
          debugPrint('🎵 AudioService返回空的最近播放列表');
          return [];
        default:
          debugPrint('🎵 AudioService未知的父媒体ID: $parentMediaId');
          return [];
      }
    } catch (e) {
      debugPrint('🎵 AudioService getChildren错误: $e');
      return [];
    }
  }
  
  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    debugPrint('🎵 AudioService收到播放媒体项目命令: ${mediaItem.title}');
    final playerService = PlayerService();
    
    // 在播放列表中查找对应的歌曲
    final index = playerService.playlist.indexWhere((track) => track.id.toString() == mediaItem.id);
    if (index >= 0) {
      await playerService.playTrackAt(index);
    } else {
      debugPrint('🎵 AudioService未找到对应的歌曲: ${mediaItem.id}');
    }
  }
  
  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    debugPrint('🎵 AudioService收到添加队列项目命令: ${mediaItem.title}');
    // 这里可以添加到播放列表的逻辑
  }
  
  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    debugPrint('🎵 AudioService收到移除队列项目命令: ${mediaItem.title}');
    // 这里可以从播放列表移除的逻辑
  }
  
  @override
  Future<void> skipToQueueItem(int index) async {
    debugPrint('🎵 AudioService收到跳转到队列项目命令: $index');
    final playerService = PlayerService();
    if (index >= 0 && index < playerService.playlist.length) {
      await playerService.playTrackAt(index);
    }
  }
  
  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    debugPrint('🎵 AudioService收到播放媒体ID命令: $mediaId');
    final playerService = PlayerService();
    
    // 在播放列表中查找对应的歌曲
    final index = playerService.playlist.indexWhere((track) => track.id.toString() == mediaId);
    if (index >= 0) {
      await playerService.playTrackAt(index);
    } else {
      debugPrint('🎵 AudioService未找到对应的歌曲ID: $mediaId');
    }
  }
  
  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    debugPrint('🎵 AudioService收到搜索播放命令: $query');
    // 这里可以实现搜索播放逻辑
  }
  
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    debugPrint('🎵 AudioService收到设置重复模式命令: $repeatMode');
    // 这里可以实现重复模式设置
  }
  
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    debugPrint('🎵 AudioService收到设置随机模式命令: $shuffleMode');
    // 这里可以实现随机模式设置
  }
  
  /// 更新播放状态（由 PlayerService 调用）
  void updatePlaybackState(PlaybackState playerState, bool playing, Duration position) {
    final processingState = _getProcessingState(playerState);
    
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
        MediaAction.skipToQueueItem,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: position,
      speed: playing ? 1.0 : 0.0,
      queueIndex: PlayerService().currentIndex >= 0 ? PlayerService().currentIndex : null,
    ));
    
    debugPrint('🎵 AudioService播放状态已更新: playing=$playing, position=${position.inSeconds}s');
  }
  
  /// 更新媒体信息（由 PlayerService 调用）
  void updateCurrentMediaItem(Track track) {
    final mediaItem = MediaItem(
      id: track.id.toString(),
      album: track.album.name,
      title: track.name,
      artist: track.artists.map((a) => a.name).join(', '),
      duration: Duration(milliseconds: track.duration),
      artUri: track.album.picUrl.isNotEmpty 
          ? Uri.parse('${track.album.picUrl}?param=300y300') 
          : null,
    );
    
    this.mediaItem.add(mediaItem);
    debugPrint('🎵 AudioService媒体信息已更新: ${track.name} - ${track.artists.map((a) => a.name).join(', ')}');
  }
  
  /// 更新播放队列（由 PlayerService 调用）
  void updatePlaylist(List<Track> tracks, int currentIndex) {
    final queueItems = tracks.map((track) => MediaItem(
      id: track.id.toString(),
      album: track.album.name,
      title: track.name,
      artist: track.artists.map((a) => a.name).join(', '),
      duration: Duration(milliseconds: track.duration),
      artUri: track.album.picUrl.isNotEmpty 
          ? Uri.parse('${track.album.picUrl}?param=300y300') 
          : null,
      playable: true,
    )).toList();
    
    queue.add(queueItems);
    debugPrint('🎵 AudioService队列已更新: ${queueItems.length}首歌曲');
  }
  
  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    debugPrint('🎵 AudioService收到更新队列命令: ${queue.length}首歌曲');
    this.queue.add(queue);
  }
  
  AudioProcessingState _getProcessingState(PlaybackState playerState) {
    switch (playerState) {
      case PlaybackState.stopped:
        return AudioProcessingState.idle;
      case PlaybackState.playing:
        return AudioProcessingState.ready;
      case PlaybackState.paused:
        return AudioProcessingState.ready;
      case PlaybackState.buffering:
        return AudioProcessingState.buffering;
    }
  }
  
  @override
  Future<void> play() async {
    debugPrint('🎵 AudioService收到播放命令 - 立即处理');
    
    try {
      final playerService = PlayerService();
      
      // 立即向系统响应，显示我们收到了命令
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: false,  // 先设为false，播放成功后会自动更新为true
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,  // 显示暂停按钮，表明准备播放
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
      ));
      
      debugPrint('🎵 当前播放列表大小: ${playerService.playlist.length}');
      debugPrint('🎵 当前索引: ${playerService.currentIndex}');
      debugPrint('🎵 当前歌曲: ${playerService.currentTrack?.name ?? "无"}');
      
      // 检查播放列表
      if (playerService.playlist.isEmpty) {
        debugPrint('🎵 播放列表为空，无法播放');
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
        ));
        return;
      }
      
      // 检查当前歌曲索引
      if (playerService.currentIndex < 0 || playerService.currentIndex >= playerService.playlist.length) {
        debugPrint('🎵 无效的歌曲索引，设置为第一首');
        await playerService.playTrackAt(0, userInitiated: false);
        return;
      }
      
      // 执行播放逻辑
      debugPrint('🎵 执行播放逻辑，当前歌曲: ${playerService.currentTrack?.name}');
      await playerService.play();
      
      // 延迟一点确保状态同步
      Future.delayed(const Duration(milliseconds: 200), () {
        final currentState = playerService.playerState;
        final isPlaying = playerService.isPlaying;
        final position = playerService.position;
        
        debugPrint('🎵 播放命令执行完毕，最终状态: playing=$isPlaying, state=$currentState');
        
        updatePlaybackState(currentState, isPlaying, position);
      });
      
    } catch (e) {
      debugPrint('🎵 AudioService播放失败: $e');
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
      ));
    }
  }
  
  @override
  Future<void> pause() async {
    debugPrint('🎵 AudioService收到暂停命令');
    await PlayerService().pause();
  }
  
  @override
  Future<void> stop() async {
    debugPrint('🎵 AudioService收到停止命令');
    await PlayerService().stop();
  }
  
  @override
  Future<void> skipToNext() async {
    debugPrint('🎵 AudioService收到下一首命令');
    await PlayerService().next();
  }
  
  @override
  Future<void> skipToPrevious() async {
    debugPrint('🎵 AudioService收到上一首命令');
    await PlayerService().previous();
  }
  
  @override
  Future<void> seek(Duration position) async {
    debugPrint('🎵 AudioService收到定位命令: ${position.inSeconds}s');
    await PlayerService().seek(position);
  }
  
  @override
  Future<void> onTaskRemoved() async {
    debugPrint('🎵 AudioService任务被移除');
    // 不要停止服务，保持后台播放
  }
  
  @override
  Future<void> onNotificationDeleted() async {
    debugPrint('🎵 AudioService通知被删除');
    // 可以选择停止播放或保持播放
  }
  
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    debugPrint('🎵 AudioService收到媒体按钮点击: $button');
    switch (button) {
      case MediaButton.media:
        final playerService = PlayerService();
        if (playerService.isPlaying) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }
}
