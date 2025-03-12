class PlaylistData {
  final String id;
  final String title;
  final String artist;
  final String artUri;
  final String audioUri;
  final String bvid;
  final int aid;
  final int cid;
  final bool multi;
  final int mid;
  final bool cached;
  final String rawTitle;
  final int duration;
  final bool dummy;
  PlaylistData({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUri,
    required this.audioUri,
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.multi,
    required this.mid,
    required this.cached,
    required this.rawTitle,
    required this.duration,
    required this.dummy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artUri': artUri,
        'audioUri': audioUri,
        'bvid': bvid,
        'aid': aid,
        'cid': cid,
        'multi': multi,
        'mid': mid,
        'cached': cached,
        'raw_title': rawTitle,
        'duration': duration,
        'dummy': dummy,
      };

  factory PlaylistData.fromJson(Map<String, dynamic> json) => PlaylistData(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        artUri: json['artUri'],
        audioUri: json['audioUri'],
        bvid: json['bvid'],
        aid: json['aid'],
        cid: json['cid'],
        multi: json['multi'],
        mid: json['mid'],
        cached: json['cached'],
        rawTitle: json['raw_title'],
        duration: json['duration'],
        dummy: json['dummy'],
      );
}
