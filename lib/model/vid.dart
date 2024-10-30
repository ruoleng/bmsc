class VidResult {
  VidResult({
    required this.bvid,
    required this.aid,
    required this.videos,
    required this.tid,
    required this.tname,
    required this.copyright,
    required this.pic,
    required this.title,
    required this.pubdate,
    required this.ctime,
    required this.desc,
    required this.state,
    required this.duration,
    required this.rights,
    required this.owner,
    required this.stat,
    required this.cid,
    required this.teenageMode,
    required this.isChargeableSeason,
    required this.isStory,
    required this.noCache,
    required this.pages,
    required this.subtitle,
    required this.isSeasonDisplay,
    required this.likeIcon,
  });
  late final String bvid;
  late final int aid;
  late final int videos;
  late final int tid;
  late final String tname;
  late final int copyright;
  late final String pic;
  late final String title;
  late final int pubdate;
  late final int ctime;
  late final String desc;
  late final int state;
  late final int duration;
  late final Rights rights;
  late final Owner owner;
  late final Stat stat;
  late final int cid;
  late final int teenageMode;
  late final bool isChargeableSeason;
  late final bool isStory;
  late final bool noCache;
  late final List<Pages> pages;
  late final Subtitle subtitle;
  late final bool isSeasonDisplay;
  late final String likeIcon;

  VidResult.fromJson(Map<String, dynamic> json) {
    bvid = json['bvid'];
    aid = json['aid'];
    videos = json['videos'];
    tid = json['tid'];
    tname = json['tname'];
    copyright = json['copyright'];
    pic = json['pic'];
    title = json['title'];
    pubdate = json['pubdate'];
    ctime = json['ctime'];
    desc = json['desc'];
    state = json['state'];
    duration = json['duration'];
    rights = Rights.fromJson(json['rights']);
    owner = Owner.fromJson(json['owner']);
    stat = Stat.fromJson(json['stat']);
    cid = json['cid'];
    teenageMode = json['teenage_mode'];
    isChargeableSeason = json['is_chargeable_season'];
    isStory = json['is_story'];
    noCache = json['no_cache'];
    pages = List.from(json['pages']).map((e) => Pages.fromJson(e)).toList();
    subtitle = Subtitle.fromJson(json['subtitle']);
    isSeasonDisplay = json['is_season_display'];
    likeIcon = json['like_icon'];
  }
}

class DescV2 {
  DescV2({
    required this.rawText,
    required this.type,
    required this.bizId,
  });
  late final String rawText;
  late final int type;
  late final int bizId;

  DescV2.fromJson(Map<String, dynamic> json) {
    rawText = json['raw_text'];
    type = json['type'];
    bizId = json['biz_id'];
  }
}

class Rights {
  Rights({
    required this.bp,
    required this.elec,
    required this.download,
    required this.movie,
    required this.pay,
    required this.hd5,
    required this.noReprint,
    required this.autoplay,
    required this.ugcPay,
    required this.isCooperation,
    required this.ugcPayPreview,
    required this.noBackground,
    required this.cleanMode,
    required this.isSteinGate,
    required this.is_360,
    required this.noShare,
    required this.arcPay,
    required this.freeWatch,
  });
  late final int bp;
  late final int elec;
  late final int download;
  late final int movie;
  late final int pay;
  late final int hd5;
  late final int noReprint;
  late final int autoplay;
  late final int ugcPay;
  late final int isCooperation;
  late final int ugcPayPreview;
  late final int noBackground;
  late final int cleanMode;
  late final int isSteinGate;
  late final int is_360;
  late final int noShare;
  late final int arcPay;
  late final int freeWatch;

  Rights.fromJson(Map<String, dynamic> json) {
    bp = json['bp'];
    elec = json['elec'];
    download = json['download'];
    movie = json['movie'];
    pay = json['pay'];
    hd5 = json['hd5'];
    noReprint = json['no_reprint'];
    autoplay = json['autoplay'];
    ugcPay = json['ugc_pay'];
    isCooperation = json['is_cooperation'];
    ugcPayPreview = json['ugc_pay_preview'];
    noBackground = json['no_background'];
    cleanMode = json['clean_mode'];
    isSteinGate = json['is_stein_gate'];
    is_360 = json['is_360'];
    noShare = json['no_share'];
    arcPay = json['arc_pay'];
    freeWatch = json['free_watch'];
  }
}

class Owner {
  Owner({
    required this.mid,
    required this.name,
    required this.face,
  });
  late final int mid;
  late final String name;
  late final String face;

  Owner.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    face = json['face'];
  }
}

class Stat {
  Stat({
    required this.aid,
    required this.view,
    required this.danmaku,
    required this.reply,
    required this.favorite,
    required this.coin,
    required this.share,
    required this.nowRank,
    required this.hisRank,
    required this.like,
    required this.dislike,
  });
  late final int aid;
  late final int view;
  late final int danmaku;
  late final int reply;
  late final int favorite;
  late final int coin;
  late final int share;
  late final int nowRank;
  late final int hisRank;
  late final int like;
  late final int dislike;
  Stat.fromJson(Map<String, dynamic> json) {
    aid = json['aid'];
    view = json['view'];
    danmaku = json['danmaku'];
    reply = json['reply'];
    favorite = json['favorite'];
    coin = json['coin'];
    share = json['share'];
    nowRank = json['now_rank'];
    hisRank = json['his_rank'];
    like = json['like'];
    dislike = json['dislike'];
  }
}

class Pages {
  Pages({
    required this.cid,
    required this.page,
    required this.from,
    required this.part,
    required this.duration,
  });
  late final int cid;
  late final int page;
  late final String from;
  late final String part;
  late final int duration;

  Pages.fromJson(Map<String, dynamic> json) {
    cid = json['cid'];
    page = json['page'];
    from = json['from'];
    part = json['part'];
    duration = json['duration'];
  }
}

class Subtitle {
  Subtitle({
    required this.allowSubmit,
    required this.list,
  });
  late final bool allowSubmit;
  late final List<dynamic> list;

  Subtitle.fromJson(Map<String, dynamic> json) {
    allowSubmit = json['allow_submit'];
    list = List.castFrom<dynamic, dynamic>(json['list']);
  }
}
