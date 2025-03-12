class Meta {
  Meta({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.artist,
    required this.mid,
    required this.duration,
    this.parts,
    this.play,
    required this.artUri,
  });
  late final String bvid;
  late final int aid;
  late final String title;
  late final String artist;
  late final int mid;
  late final int duration;
  late final int? parts;
  late final int? play;
  late final String artUri;

  Meta.fromJson(Map<String, dynamic> json) {
    bvid = json['bvid'];
    aid = json['aid'];
    title = json['title'];
    artist = json['artist'];
    artUri = json['artUri'];
    mid = json['mid'];
    duration = json['duration'];
    parts = json['parts'];
  }

  Map<String, dynamic> toJson() {
    return {
      'bvid': bvid,
      'title': title,
      'artist': artist,
      'mid': mid,
      'aid': aid,
      'duration': duration,
      'artUri': artUri,
      'parts': parts,
    };
  }
}
