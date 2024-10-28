class FavDetail {
  FavDetail({
    required this.info,
    required this.medias,
    required this.hasMore,
  });
  late final Info info;
  late final List<Medias> medias;
  late final bool hasMore;

  FavDetail.fromJson(Map<String, dynamic> json) {
    info = Info.fromJson(json['info']);
    medias = List.from(json['medias']).map((e) => Medias.fromJson(e)).toList();
    hasMore = json['has_more'];
  }
}

class Info {
  Info({
    required this.id,
    required this.fid,
    required this.mid,
    required this.attr,
    required this.title,
    required this.cover,
    required this.upper,
    required this.coverType,
    required this.cntInfo,
    required this.type,
    required this.intro,
    required this.ctime,
    required this.mtime,
    required this.state,
    required this.favState,
    required this.mediaCount,
  });
  late final int id;
  late final int fid;
  late final int mid;
  late final int attr;
  late final String title;
  late final String cover;
  late final Upper upper;
  late final int coverType;
  late final CntInfo cntInfo;
  late final int type;
  late final String intro;
  late final int ctime;
  late final int mtime;
  late final int state;
  late final int favState;
  late final int mediaCount;

  Info.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    fid = json['fid'];
    mid = json['mid'];
    attr = json['attr'];
    title = json['title'];
    cover = json['cover'];
    upper = Upper.fromJson(json['upper']);
    coverType = json['cover_type'];
    cntInfo = CntInfo.fromJson(json['cnt_info']);
    type = json['type'];
    intro = json['intro'];
    ctime = json['ctime'];
    mtime = json['mtime'];
    state = json['state'];
    favState = json['fav_state'];
    mediaCount = json['media_count'];
  }
}

class Upper {
  Upper({
    required this.mid,
    required this.name,
    required this.face,
  });
  late final int mid;
  late final String name;
  late final String face;

  Upper.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    face = json['face'];
  }
}

class CntInfo {
  CntInfo({
    required this.collect,
    required this.play,
  });
  late final int collect;
  late final int play;

  CntInfo.fromJson(Map<String, dynamic> json) {
    collect = json['collect'];
    play = json['play'];
  }
}

class Medias {
  Medias({
    required this.id,
    required this.type,
    required this.title,
    required this.cover,
    required this.intro,
    required this.page,
    required this.duration,
    required this.upper,
    required this.cntInfo,
    required this.link,
    required this.ctime,
    required this.pubtime,
    required this.favTime,
    required this.bvid,
  });
  late final int id;
  late final int type;
  late final String title;
  late final String cover;
  late final String intro;
  late final int page;
  late final int duration;
  late final Upper upper;
  late final CntInfo cntInfo;
  late final String link;
  late final int ctime;
  late final int pubtime;
  late final int favTime;
  late final String bvid;

  Medias.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    type = json['type'];
    title = json['title'];
    cover = json['cover'];
    intro = json['intro'];
    page = json['page'];
    duration = json['duration'];
    upper = Upper.fromJson(json['upper']);
    cntInfo = CntInfo.fromJson(json['cnt_info']);
    link = json['link'];
    ctime = json['ctime'];
    pubtime = json['pubtime'];
    favTime = json['fav_time'];
    bvid = json['bvid'];
  }
}
