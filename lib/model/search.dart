class SearchResult {
  SearchResult({
    required this.seid,
    required this.page,
    required this.pagesize,
    required this.numResults,
    required this.numPages,
    required this.suggestKeyword,
    required this.rqtType,
    required this.eggHit,
    required this.result,
    required this.showColumn,
  });
  late final String seid;
  late final int page;
  late final int pagesize;
  late final int numResults;
  late final int numPages;
  late final String suggestKeyword;
  late final String rqtType;
  late final int eggHit;
  late final List<Result> result;
  late final int showColumn;

  SearchResult.fromJson(Map<String, dynamic> json) {
    seid = json['seid'];
    page = json['page'];
    pagesize = json['pagesize'];
    numResults = json['numResults'];
    numPages = json['numPages'];
    suggestKeyword = json['suggest_keyword'];
    rqtType = json['rqt_type'];
    eggHit = json['egg_hit'];
    result = (json['result'] as List<dynamic>?)
            ?.map((e) => Result.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    showColumn = json['show_column'];
  }
}

class Result {
  Result({
    required this.author,
    required this.mid,
    required this.typeid,
    required this.typename,
    required this.aid,
    required this.bvid,
    required this.title,
    required this.pic,
    required this.play,
    required this.duration,
  });
  late final String author;
  late final int mid;
  late final String typeid;
  late final String typename;
  late final int aid;
  late final String bvid;
  late final String title;
  late final String pic;
  late final int play;
  late final String duration;

  Result.fromJson(Map<String, dynamic> json) {
    author = json['author'];
    mid = json['mid'];
    typeid = json['typeid'];
    typename = json['typename'];
    aid = json['aid'];
    bvid = json['bvid'];
    title = json['title'];
    pic = json['pic'];
    play = json['play'];
    duration = json['duration'];
  }
}
