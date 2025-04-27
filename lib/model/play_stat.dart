class PlayStat {
  final String bvid;
  final int lastPlayed;
  final int totalPlayTime;
  final int playCount;

  // Optional fields from meta table join
  final String? title;
  final String? artist;
  final String? artUri;
  final int? duration;

  PlayStat({
    required this.bvid,
    required this.lastPlayed,
    required this.totalPlayTime,
    required this.playCount,
    this.title,
    this.artist,
    this.artUri,
    this.duration,
  });

  factory PlayStat.fromJson(Map<String, dynamic> json) {
    return PlayStat(
      bvid: json['bvid'] as String,
      lastPlayed: json['last_played'] as int,
      totalPlayTime: json['total_play_time'] as int,
      playCount: json['play_count'] as int,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      artUri: json['artUri'] as String?,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bvid': bvid,
      'last_played': lastPlayed,
      'total_play_time': totalPlayTime,
      'play_count': playCount,
      // Only include the meta fields if they're not null
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (artUri != null) 'artUri': artUri,
      if (duration != null) 'duration': duration,
    };
  }

  Map<String, dynamic> toDbJson() {
    return {
      'bvid': bvid,
      'last_played': lastPlayed,
      'total_play_time': totalPlayTime,
      'play_count': playCount,
    };
  }

  @override
  String toString() {
    return 'PlayStat{bvid: $bvid, title: $title, playCount: $playCount, lastPlayed: $lastPlayed}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayStat && other.bvid == bvid;
  }

  @override
  int get hashCode => bvid.hashCode;
}
