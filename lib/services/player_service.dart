import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xcmusic_mobile/utils/app_logger.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import '../models/playlist.dart';
import '../services/api_manager.dart';
import '../utils/global_config.dart';

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
  
  // 播放状态
  PlaybackState _playerState = PlaybackState.stopped;
  PlayMode _playMode = PlayMode.listLoop;
  
  // 播放列表
  List<Track> _playlist = [];
  int _currentIndex = -1;
  
  // 播放进度
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // 当前播放歌曲的URL
  String? _currentUrl;
  
  // 上次保存状态的时间，避免频繁保存
  DateTime? _lastSaveTime;

  /// 初始化播放器
  void _initializePlayer() {
    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) {
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
      notifyListeners();
    });

    // 监听播放完成（只在这里监听一次）
    _audioPlayer.onPlayerComplete.listen((_) {
      AppLogger.info('AudioPlayer 播放完成事件触发');
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

  /// 初始化播放器
  Future<void> initialize() async {
    // 加载保存的播放状态
    await _loadSavedState();
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
      AppLogger.info('播放状态已保存');
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
        AppLogger.warning('没有找到保存的播放状态文件');
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

      AppLogger.info('播放状态已恢复: ${_playlist.length} 首歌曲，当前索引: $_currentIndex');

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
      AppLogger.info('正在恢复播放状态...');

      // 读取用户设置（只关心自动播放）
      bool shouldAutoPlay = false;
      
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          final prefs = await SharedPreferences.getInstance();
          shouldAutoPlay = prefs.getBool('auto_play') ?? false;
          break; // 成功读取设置，退出重试循环
        } catch (e) {
          retryCount++;
          AppLogger.error('读取用户设置失败 (尝试 $retryCount/$maxRetries): $e');
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          } else {
            AppLogger.warning('多次尝试后仍无法读取用户设置，将使用默认设置');
            // 使用默认设置
            shouldAutoPlay = false;
          }
        }
      }

      AppLogger.info('用户设置: shouldAutoPlay=$shouldAutoPlay');

      // 重新获取播放链接
      final url = await _getSongUrl(currentTrack!.id.toString());
      if (url != null) {
        _currentUrl = url;
        
        if (shouldAutoPlay && _playerState == PlaybackState.playing) {
          // 如果用户开启了自动播放且之前是播放状态，则开始播放
          await _audioPlayer.play(UrlSource(url));
        } else {
          // 否则只设置音频源但不播放
          await _audioPlayer.setSource(UrlSource(url));
          _playerState = PlaybackState.paused;
          notifyListeners();
          AppLogger.info('播放状态已恢复为暂停');
        }
      } else {
        AppLogger.error('无法获取播放链接，播放状态恢复失败');
        _playerState = PlaybackState.stopped;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('恢复播放状态失败: $e');
      _playerState = PlaybackState.stopped;
      notifyListeners();
    }
  }

  /// 设置播放列表并开始播放
  Future<void> playPlaylist(List<Track> tracks, {int startIndex = 0}) async {
    _playlist = List.from(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    await _playCurrentTrack();
    await _saveState(); // 保存状态
  }

  /// 添加歌曲到播放列表
  void addTrack(Track track) {
    _playlist.add(track);
    notifyListeners();
    // 异步保存状态，不阻塞UI
    _saveState().catchError((e) {
      AppLogger.error('保存播放状态失败', e);
    });
  }

  /// 添加多首歌曲到播放列表
  void addTracks(List<Track> tracks) {
    _playlist.addAll(tracks);
    notifyListeners();
    // 异步保存状态，不阻塞UI
    _saveState().catchError((e) {
      AppLogger.error('保存播放状态失败', e);
    });
  }

  /// 从播放列表移除歌曲
  void removeTrack(int index) {
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
      notifyListeners();
    }
  }

  /// 清空播放列表
  Future<void> clearPlaylist() async {
    await stop();
    _playlist.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  /// 播放指定索引的歌曲
  Future<void> playTrackAt(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playCurrentTrack();
    }
  }

  /// 从播放列表中移除指定索引的歌曲
  Future<void> removeFromPlaylist(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    
    if (index == _currentIndex) {
      // 如果移除的是当前播放的歌曲
      if (_playlist.length > 1) {
        // 如果不是最后一首，播放下一首；如果是最后一首，播放前一首
        if (index == _playlist.length - 1) {
          _currentIndex = index - 1;
        }
        _playlist.removeAt(index);
        await _playCurrentTrack();
      } else {
        // 如果只有一首歌，清空播放列表
        await clearPlaylist();
      }
    } else {
      // 移除的不是当前播放的歌曲
      _playlist.removeAt(index);
      if (index < _currentIndex) {
        // 如果移除的歌曲在当前歌曲之前，更新当前索引
        _currentIndex--;
      }
    }
    
    notifyListeners();
  }

  /// 设置播放列表并开始播放
  Future<void> setPlaylist(List<Track> tracks, [int startIndex = 0]) async {
    _playlist = List.from(tracks);
    _currentIndex = startIndex.clamp(0, tracks.length - 1);
    
    if (_playlist.isNotEmpty) {
      await _playCurrentTrack();
    }
    notifyListeners();
    // 异步保存状态，不阻塞UI
    _saveState().catchError((e) {
      AppLogger.error('保存播放状态失败', e);
    });
  }

  /// 播放当前歌曲
  Future<void> _playCurrentTrack() async {
    if (currentTrack == null) return;

    try {
      _playerState = PlaybackState.buffering;
      notifyListeners();

      // 获取播放链接
      final url = await _getSongUrl(currentTrack!.id.toString());
      if (url != null) {
        _currentUrl = url;
        
        // 重置进度并正常播放
        _position = Duration.zero;
        await _audioPlayer.play(UrlSource(url));
      } else {
        // 如果获取不到播放链接，跳到下一首
        await next();
      }
    } catch (e) {
      debugPrint('播放失败: $e');
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
          
          if (url != null && url.isNotEmpty) {
            // 确保使用HTTPS协议
            String finalUrl = url;
            if (finalUrl.startsWith('http://')) {
              finalUrl = finalUrl.replaceFirst('http://', 'https://');
            }
            return finalUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('获取播放链接失败: $e');
    }
    return null;
  }

  /// 播放/暂停
  Future<void> playPause() async {
    if (_playerState == PlaybackState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// 播放
  Future<void> play() async {
    if (_currentUrl != null) {
      // 如果已经有音频源，直接恢复播放
      await _audioPlayer.resume();
    } else if (currentTrack != null) {
      // 如果没有音频源，重新加载
      await _playCurrentTrack();
    }
  }

  /// 暂停
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _position = Duration.zero;
    _currentUrl = null;
  }

  /// 下一首
  Future<void> next() async {
    AppLogger.info('next() 调用开始，当前播放模式: $_playMode, 当前索引: $_currentIndex, 播放列表长度: ${_playlist.length}');
    
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
  Future<void> previous() async {
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

  /// 释放资源
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
