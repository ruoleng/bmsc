class FavResult {
  FavResult({
    required this.count,
    required this.list,
  });
  late final int count;
  late final List<Fav> list;

  FavResult.fromJson(Map<String, dynamic> json) {
    count = json['count'];
    list = List.from(json['list']).map((e) => Fav.fromJson(e)).toList();
  }
}

class Fav {
  Fav({
    required this.id,
    required this.fid,
    required this.mid,
    required this.attr,
    required this.title,
    required this.favState,
    required this.mediaCount,
  });
  late final int id;
  late final int fid;
  late final int mid;
  late final int attr;
  late final String title;
  late final int favState;
  late final int mediaCount;

  Fav.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    fid = json['fid'];
    mid = json['mid'];
    attr = json['attr'];
    title = json['title'];
    favState = json['fav_state'];
    mediaCount = json['media_count'];
  }
}
