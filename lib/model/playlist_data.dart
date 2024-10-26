class PlaylistData {
  final String id;
  final String title;
  final String artist;
  final String artUri;
  final String audioUri;
  final String bvid;
  final int cid;
  final int quality;
  final int mid;
  final bool cached;

  PlaylistData({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUri,
    required this.audioUri,
    required this.bvid,
    required this.cid,
    required this.quality,
    required this.mid,
    required this.cached,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artUri': artUri,
        'audioUri': audioUri,
        'bvid': bvid,
        'cid': cid,
        'quality': quality,
        'mid': mid,
        'cached': cached,
      };

  factory PlaylistData.fromJson(Map<String, dynamic> json) => PlaylistData(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        artUri: json['artUri'],
        audioUri: json['audioUri'],
        bvid: json['bvid'],
        cid: json['cid'],
        quality: json['quality'],
        mid: json['mid'],
        cached: json['cached'],
      );
}
