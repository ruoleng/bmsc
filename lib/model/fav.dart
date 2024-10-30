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
    required this.title,
    this.favState = 0,
    required this.mediaCount,
  });
  late final int id;
  late final String title;
  int favState = 0;
  late final int mediaCount;

  Fav.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    favState = json['fav_state'];
    mediaCount = json['media_count'];
  }
}
