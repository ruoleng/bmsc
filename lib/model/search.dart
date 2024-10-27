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

class CostTime {
  CostTime({
    required this.paramsCheck,
    required this.illegalHandler,
    required this.asResponseFormat,
    required this.asRequest,
    required this.saveCache,
    required this.deserializeResponse,
    required this.asRequestFormat,
    required this.total,
    required this.mainHandler,
  });
  late final String paramsCheck;
  late final String illegalHandler;
  late final String asResponseFormat;
  late final String asRequest;
  late final String saveCache;
  late final String deserializeResponse;
  late final String asRequestFormat;
  late final String total;
  late final String mainHandler;

  CostTime.fromJson(Map<String, dynamic> json) {
    paramsCheck = json['params_check'];
    illegalHandler = json['illegal_handler'];
    asResponseFormat = json['as_response_format'];
    asRequest = json['as_request'];
    saveCache = json['save_cache'];
    deserializeResponse = json['deserialize_response'];
    asRequestFormat = json['as_request_format'];
    total = json['total'];
    mainHandler = json['main_handler'];
  }
}

class Result {
  Result({
    required this.type,
    required this.id,
    required this.author,
    required this.mid,
    required this.typeid,
    required this.typename,
    required this.arcurl,
    required this.aid,
    required this.bvid,
    required this.title,
    required this.description,
    required this.arcrank,
    required this.pic,
    required this.play,
    required this.videoReview,
    required this.favorites,
    required this.tag,
    required this.review,
    required this.pubdate,
    required this.senddate,
    required this.duration,
    required this.badgepay,
    required this.hitColumns,
    required this.viewType,
    required this.isPay,
    required this.isUnionVideo,
    required this.rankScore,
  });
  late final String type;
  late final int id;
  late final String author;
  late final int mid;
  late final String typeid;
  late final String typename;
  late final String arcurl;
  late final int aid;
  late final String bvid;
  late final String title;
  late final String description;
  late final String arcrank;
  late final String pic;
  late final int play;
  late final int videoReview;
  late final int favorites;
  late final String tag;
  late final int review;
  late final int pubdate;
  late final int senddate;
  late final String duration;
  late final bool badgepay;
  late final List<String> hitColumns;
  late final String viewType;
  late final int isPay;
  late final int isUnionVideo;
  late final int rankScore;

  Result.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    id = json['id'];
    author = json['author'];
    mid = json['mid'];
    typeid = json['typeid'];
    typename = json['typename'];
    arcurl = json['arcurl'];
    aid = json['aid'];
    bvid = json['bvid'];
    title = json['title'];
    description = json['description'];
    arcrank = json['arcrank'];
    pic = json['pic'];
    play = json['play'];
    videoReview = json['video_review'];
    favorites = json['favorites'];
    tag = json['tag'];
    review = json['review'];
    pubdate = json['pubdate'];
    senddate = json['senddate'];
    duration = json['duration'];
    badgepay = json['badgepay'];
    hitColumns = (json['hit_columns'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];

    viewType = json['view_type'];
    isPay = json['is_pay'];
    isUnionVideo = json['is_union_video'];
    rankScore = json['rank_score'];
  }
}
