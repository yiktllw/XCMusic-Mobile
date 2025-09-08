/// 歌单详情数据模型
class PlaylistDetail {
  final int id;
  final String name;
  final String coverImgUrl;
  final int createTime;
  final int playCount;
  final int trackCount;
  final String description;
  final bool subscribed;
  final Creator creator;
  final List<Track> tracks;
  final List<TrackId> trackIds;

  PlaylistDetail({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    required this.createTime,
    required this.playCount,
    required this.trackCount,
    required this.description,
    required this.subscribed,
    required this.creator,
    required this.tracks,
    required this.trackIds,
  });

  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final playlist = json['playlist'] as Map<String, dynamic>?;
    if (playlist == null) {
      throw Exception('歌单数据格式错误: playlist 字段不存在');
    }
    
    return PlaylistDetail(
      id: (playlist['id'] ?? 0) as int,
      name: (playlist['name'] ?? '未知歌单') as String,
      coverImgUrl: (playlist['coverImgUrl'] ?? playlist['picUrl'] ?? '') as String,
      createTime: (playlist['createTime'] ?? 0) as int,
      playCount: (playlist['playCount'] ?? 0) as int,
      trackCount: (playlist['trackCount'] ?? 0) as int,
      description: (playlist['description'] ?? '') as String,
      subscribed: (playlist['subscribed'] ?? false) as bool,
      creator: Creator.fromJson(playlist['creator'] as Map<String, dynamic>? ?? {}),
      tracks: (playlist['tracks'] as List?)
          ?.map((track) => Track.fromJson(track as Map<String, dynamic>))
          .toList() ?? [],
      trackIds: (playlist['trackIds'] as List?)
          ?.map((trackId) => TrackId.fromJson(trackId as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// 创建者信息
class Creator {
  final int userId;
  final String nickname;
  final String avatarUrl;
  final String signature;

  Creator({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.signature,
  });

  factory Creator.fromJson(Map<String, dynamic> json) {
    return Creator(
      userId: (json['userId'] ?? json['id'] ?? 0) as int,
      nickname: (json['nickname'] ?? json['name'] ?? '未知用户') as String,
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '') as String,
      signature: (json['signature'] ?? '') as String,
    );
  }
}

/// 歌曲信息
class Track {
  final int id;
  final String name;
  final List<String> tns; // 歌曲译名
  final List<Artist> artists;
  final Album album;
  final int duration;
  final double popularity;
  final int fee;
  final String? additionalTitle;

  Track({
    required this.id,
    required this.name,
    this.tns = const [],
    required this.artists,
    required this.album,
    required this.duration,
    required this.popularity,
    required this.fee,
    this.additionalTitle,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '未知歌曲') as String,
      tns: (json['tns'] as List?)?.map((e) => e.toString()).toList() ?? [],
      artists: (json['ar'] as List?)
          ?.map((artist) => Artist.fromJson(artist as Map<String, dynamic>))
          .toList() ?? [],
      album: Album.fromJson(json['al'] as Map<String, dynamic>? ?? {}),
      duration: (json['dt'] ?? 0) as int,
      popularity: (json['pop'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] ?? 0) as int,
      additionalTitle: json['additionalTitle'] as String?,
    );
  }

  /// 格式化时长为 mm:ss 格式
  String get formattedDuration {
    final minutes = (duration / 60000).floor();
    final seconds = ((duration % 60000) / 1000).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取艺术家名称字符串
  String get artistNames {
    return artists.map((artist) => artist.name).join(' / ');
  }

  /// 是否为VIP歌曲
  bool get isVip {
    return fee == 1 || fee == 4;
  }
}

/// 艺术家信息
class Artist {
  final int id;
  final String name;

  Artist({
    required this.id,
    required this.name,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '未知艺术家') as String,
    );
  }
}

/// 专辑信息
class Album {
  final int id;
  final String name;
  final List<String> tns; // 专辑译名
  final String picUrl;

  Album({
    required this.id,
    required this.name,
    this.tns = const [],
    required this.picUrl,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '未知专辑') as String,
      tns: (json['tns'] as List?)?.map((e) => e.toString()).toList() ?? [],
      picUrl: (json['picUrl'] ?? json['pic'] ?? '') as String,
    );
  }
}

/// 歌曲ID信息
class TrackId {
  final int id;
  final int v;
  final int t;

  TrackId({
    required this.id,
    required this.v,
    required this.t,
  });

  factory TrackId.fromJson(Map<String, dynamic> json) {
    return TrackId(
      id: (json['id'] ?? 0) as int,
      v: (json['v'] ?? 0) as int,
      t: (json['t'] ?? 0) as int,
    );
  }
}
