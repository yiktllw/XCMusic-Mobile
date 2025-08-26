class Album {
  final int id;
  final String name;
  final String picUrl;
  final int size;
  final List<String> aliases;
  final List<Artist> artists;
  final int subTime;
  final List<String> messages;

  Album({
    required this.id,
    required this.name,
    required this.picUrl,
    required this.size,
    required this.aliases,
    required this.artists,
    required this.subTime,
    required this.messages,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int,
      name: json['name'] as String,
      picUrl: json['picUrl'] as String,
      size: json['size'] as int,
      aliases: List<String>.from(json['alias'] ?? []),
      artists: (json['artists'] as List?)
              ?.map((artist) => Artist.fromJson(artist as Map<String, dynamic>))
              .toList() ?? [],
      subTime: json['subTime'] as int,
      messages: List<String>.from(json['msg'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'picUrl': picUrl,
      'size': size,
      'alias': aliases,
      'artists': artists.map((artist) => artist.toJson()).toList(),
      'subTime': subTime,
      'msg': messages,
    };
  }

  String get artistNames => artists.map((artist) => artist.name).join(', ');
  
  String get displayName {
    if (aliases.isNotEmpty) {
      return '$name (${aliases.first})';
    }
    return name;
  }
}

class Artist {
  final int id;
  final String name;
  final String? picUrl;
  final String? img1v1Url;
  final List<String> aliases;

  Artist({
    required this.id,
    required this.name,
    this.picUrl,
    this.img1v1Url,
    required this.aliases,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int,
      name: json['name'] as String,
      picUrl: json['picUrl'] as String?,
      img1v1Url: json['img1v1Url'] as String?,
      aliases: List<String>.from(json['alias'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'picUrl': picUrl,
      'img1v1Url': img1v1Url,
      'alias': aliases,
    };
  }
}

class AlbumSublistResponse {
  final List<Album> albums;
  final int count;
  final bool hasMore;
  final int paidCount;
  final int code;

  AlbumSublistResponse({
    required this.albums,
    required this.count,
    required this.hasMore,
    required this.paidCount,
    required this.code,
  });

  factory AlbumSublistResponse.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>;
    return AlbumSublistResponse(
      albums: (body['data'] as List?)
              ?.map((album) => Album.fromJson(album as Map<String, dynamic>))
              .toList() ?? [],
      count: body['count'] as int,
      hasMore: body['hasMore'] as bool,
      paidCount: body['paidCount'] as int,
      code: body['code'] as int,
    );
  }
}