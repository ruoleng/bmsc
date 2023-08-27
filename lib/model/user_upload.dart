class UserUploadResult {
  UserUploadResult({
    required this.list,
    required this.page,
    required this.isRisk,
    required this.gaiaResType,
  });
  late final ListData list;
  late final Page page;
  late final bool isRisk;
  late final int gaiaResType;

  UserUploadResult.fromJson(Map<String, dynamic> json) {
    list = ListData.fromJson(json['list']);
    page = Page.fromJson(json['page']);
    isRisk = json['is_risk'];
    gaiaResType = json['gaia_res_type'];
  }
}

class ListData {
  ListData({
    required this.vlist,
  });
  late final List<Video> vlist;

  ListData.fromJson(Map<String, dynamic> json) {
    vlist = List.from(json['vlist']).map((e) => Video.fromJson(e)).toList();
  }
}

class Video {
  Video({
    required this.comment,
    required this.typeid,
    required this.play,
    required this.pic,
    required this.subtitle,
    required this.description,
    required this.copyright,
    required this.title,
    required this.review,
    required this.author,
    required this.mid,
    required this.created,
    required this.length,
    required this.videoReview,
    required this.aid,
    required this.bvid,
    required this.hideClick,
    required this.isPay,
    required this.isUnionVideo,
    required this.isSteinsGate,
    required this.isLivePlayback,
    this.meta,
    required this.isAvoided,
    required this.attribute,
    required this.isChargingArc,
    required this.vt,
    required this.enableVt,
    required this.vtDisplay,
  });
  late final int comment;
  late final int typeid;
  late final int play;
  late final String pic;
  late final String subtitle;
  late final String description;
  late final String copyright;
  late final String title;
  late final int review;
  late final String author;
  late final int mid;
  late final int created;
  late final String length;
  late final int videoReview;
  late final int aid;
  late final String bvid;
  late final bool hideClick;
  late final int isPay;
  late final int isUnionVideo;
  late final int isSteinsGate;
  late final int isLivePlayback;
  late final Meta? meta;
  late final int isAvoided;
  late final int attribute;
  late final bool isChargingArc;
  late final int vt;
  late final int enableVt;
  late final String vtDisplay;

  Video.fromJson(Map<String, dynamic> json) {
    comment = json['comment'];
    typeid = json['typeid'];
    play = json['play'];
    pic = json['pic'];
    subtitle = json['subtitle'];
    description = json['description'];
    copyright = json['copyright'];
    title = json['title'];
    review = json['review'];
    author = json['author'];
    mid = json['mid'];
    created = json['created'];
    length = json['length'];
    videoReview = json['video_review'];
    aid = json['aid'];
    bvid = json['bvid'];
    hideClick = json['hide_click'];
    isPay = json['is_pay'];
    isUnionVideo = json['is_union_video'];
    isSteinsGate = json['is_steins_gate'];
    isLivePlayback = json['is_live_playback'];
    meta = null;
    isAvoided = json['is_avoided'];
    attribute = json['attribute'];
    isChargingArc = json['is_charging_arc'];
    vt = json['vt'];
    enableVt = json['enable_vt'];
    vtDisplay = json['vt_display'];
  }
}

class Meta {
  Meta({
    required this.id,
    required this.title,
    required this.cover,
    required this.mid,
    required this.intro,
    required this.signState,
    required this.attribute,
    required this.stat,
    required this.epCount,
    required this.firstAid,
    required this.ptime,
    required this.epNum,
  });
  late final int id;
  late final String title;
  late final String cover;
  late final int mid;
  late final String intro;
  late final int signState;
  late final int attribute;
  late final Stat stat;
  late final int epCount;
  late final int firstAid;
  late final int ptime;
  late final int epNum;

  Meta.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    cover = json['cover'];
    mid = json['mid'];
    intro = json['intro'];
    signState = json['sign_state'];
    attribute = json['attribute'];
    stat = Stat.fromJson(json['stat']);
    epCount = json['ep_count'];
    firstAid = json['first_aid'];
    ptime = json['ptime'];
    epNum = json['ep_num'];
  }
}

class Stat {
  Stat({
    required this.seasonId,
    required this.view,
    required this.danmaku,
    required this.reply,
    required this.favorite,
    required this.coin,
    required this.share,
    required this.like,
    required this.mtime,
    required this.vt,
    required this.vv,
  });
  late final int seasonId;
  late final int view;
  late final int danmaku;
  late final int reply;
  late final int favorite;
  late final int coin;
  late final int share;
  late final int like;
  late final int mtime;
  late final int vt;
  late final int vv;

  Stat.fromJson(Map<String, dynamic> json) {
    seasonId = json['season_id'];
    view = json['view'];
    danmaku = json['danmaku'];
    reply = json['reply'];
    favorite = json['favorite'];
    coin = json['coin'];
    share = json['share'];
    like = json['like'];
    mtime = json['mtime'];
    vt = json['vt'];
    vv = json['vv'];
  }
}

class Page {
  Page({
    required this.pn,
    required this.ps,
    required this.count,
  });
  late final int pn;
  late final int ps;
  late final int count;

  Page.fromJson(Map<String, dynamic> json) {
    pn = json['pn'];
    ps = json['ps'];
    count = json['count'];
  }
}
