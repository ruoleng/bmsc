class Entity {
  late final int aid;
  late final int cid;
  late final String bvid;
  late final String artist;
  late final int part;
  late final int duration;
  late final int excluded;
  late final String partTitle;
  late final String bvidTitle;
  late final String artUri;

  Entity({
    required this.bvid,
    required this.cid,
    required this.aid,
    required this.part,
    required this.duration,
    required this.artist,
    required this.artUri,
    required this.partTitle,
    required this.bvidTitle,
    required this.excluded,
  });

  Entity.fromJson(Map<String, dynamic> json) {
    aid = json['aid'];
    cid = json['cid'];
    bvid = json['bvid'];
    artist = json['artist'];
    part = json['part'];
    duration = json['duration'];
    excluded = json['excluded'];
    partTitle = json['part_title'];
    bvidTitle = json['bvid_title'];
    artUri = json['art_uri'];
  }

  Map<String, dynamic> toJson() {
    return {
      'aid': aid,
      'cid': cid,
      'bvid': bvid,
      'artist': artist,
      'part': part,
      'duration': duration,
      'excluded': excluded,
      'part_title': partTitle,
      'bvid_title': bvidTitle,
      'art_uri': artUri,
    };
  }
}
