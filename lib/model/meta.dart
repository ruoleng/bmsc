class Meta {
  Meta({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.artist,
    required this.mid,
    required this.duration,
    required this.parts,
    required this.artUri,
  });
  late final String bvid;
  late final int aid;
  late final String title;
  late final String artist;
  late final int mid;
  late final int duration;
  late final int parts;
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
      'aid': aid,
      'title': title,
      'artist': artist,
      'artUri': artUri,
      'mid': mid,
      'duration': duration,
      'parts': parts,
    };
  }
}
