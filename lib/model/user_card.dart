class UserInfoResult {
  UserInfoResult({
    required this.card,
    required this.following,
    required this.archiveCount,
    required this.articleCount,
    required this.follower,
    required this.likeNum,
  });
  late final Card card;
  late final bool following;
  late final int archiveCount;
  late final int articleCount;
  late final int follower;
  late final int likeNum;

  UserInfoResult.fromJson(Map<String, dynamic> json) {
    card = Card.fromJson(json['card']);
    following = json['following'];
    archiveCount = json['archive_count'];
    articleCount = json['article_count'];
    follower = json['follower'];
    likeNum = json['like_num'];
  }
}

class Card {
  Card({
    required this.mid,
    required this.name,
    required this.approve,
    required this.sex,
    required this.rank,
    required this.face,
    required this.faceNft,
    required this.faceNftType,
    required this.regtime,
    required this.spacesta,
    required this.birthday,
    required this.place,
    required this.description,
    required this.article,
    required this.attentions,
    required this.fans,
    required this.friend,
    required this.attention,
    required this.sign,
    required this.levelInfo,
    required this.pendant,
    required this.nameplate,
    required this.official,
    required this.officialVerify,
    required this.vip,
    required this.isSeniorMember,
  });
  late final String mid;
  late final String name;
  late final bool approve;
  late final String sex;
  late final String rank;
  late final String face;
  late final int faceNft;
  late final int faceNftType;
  late final int regtime;
  late final int spacesta;
  late final String birthday;
  late final String place;
  late final String description;
  late final int article;
  late final List<dynamic> attentions;
  late final int fans;
  late final int friend;
  late final int attention;
  late final String sign;
  late final LevelInfo levelInfo;
  late final Pendant pendant;
  late final Nameplate nameplate;
  late final Official official;
  late final OfficialVerify officialVerify;
  late final Vip vip;
  late final int isSeniorMember;

  Card.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    approve = json['approve'];
    sex = json['sex'];
    rank = json['rank'];
    face = json['face'];
    faceNft = json['face_nft'];
    faceNftType = json['face_nft_type'];
    regtime = json['regtime'];
    spacesta = json['spacesta'];
    birthday = json['birthday'];
    place = json['place'];
    description = json['description'];
    article = json['article'];
    attentions = List.castFrom<dynamic, dynamic>(json['attentions']);
    fans = json['fans'];
    friend = json['friend'];
    attention = json['attention'];
    sign = json['sign'];
    levelInfo = LevelInfo.fromJson(json['level_info']);
    pendant = Pendant.fromJson(json['pendant']);
    nameplate = Nameplate.fromJson(json['nameplate']);
    official = Official.fromJson(json['Official']);
    officialVerify = OfficialVerify.fromJson(json['official_verify']);
    vip = Vip.fromJson(json['vip']);
    isSeniorMember = json['is_senior_member'];
  }
}

class LevelInfo {
  LevelInfo({
    required this.currentLevel,
    required this.currentMin,
    required this.currentExp,
    required this.nextExp,
  });
  late final int currentLevel;
  late final int currentMin;
  late final int currentExp;
  late final int nextExp;

  LevelInfo.fromJson(Map<String, dynamic> json) {
    currentLevel = json['current_level'];
    currentMin = json['current_min'];
    currentExp = json['current_exp'];
    nextExp = json['next_exp'];
  }
}

class Pendant {
  Pendant({
    required this.pid,
    required this.name,
    required this.image,
    required this.expire,
    required this.imageEnhance,
    required this.imageEnhanceFrame,
  });
  late final int pid;
  late final String name;
  late final String image;
  late final int expire;
  late final String imageEnhance;
  late final String imageEnhanceFrame;

  Pendant.fromJson(Map<String, dynamic> json) {
    pid = json['pid'];
    name = json['name'];
    image = json['image'];
    expire = json['expire'];
    imageEnhance = json['image_enhance'];
    imageEnhanceFrame = json['image_enhance_frame'];
  }
}

class Nameplate {
  Nameplate({
    required this.nid,
    required this.name,
    required this.image,
    required this.imageSmall,
    required this.level,
    required this.condition,
  });
  late final int nid;
  late final String name;
  late final String image;
  late final String imageSmall;
  late final String level;
  late final String condition;

  Nameplate.fromJson(Map<String, dynamic> json) {
    nid = json['nid'];
    name = json['name'];
    image = json['image'];
    imageSmall = json['image_small'];
    level = json['level'];
    condition = json['condition'];
  }
}

class Official {
  Official({
    required this.role,
    required this.title,
    required this.desc,
    required this.type,
  });
  late final int role;
  late final String title;
  late final String desc;
  late final int type;

  Official.fromJson(Map<String, dynamic> json) {
    role = json['role'];
    title = json['title'];
    desc = json['desc'];
    type = json['type'];
  }
}

class OfficialVerify {
  OfficialVerify({
    required this.type,
    required this.desc,
  });
  late final int type;
  late final String desc;

  OfficialVerify.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    desc = json['desc'];
  }
}

class Vip {
  Vip({
    required this.type,
    required this.status,
    required this.dueDate,
    required this.vipPayType,
    required this.themeType,
    required this.label,
    required this.avatarSubscript,
    required this.nicknameColor,
    required this.role,
    required this.avatarSubscriptUrl,
    required this.tvVipStatus,
    required this.tvVipPayType,
    required this.tvDueDate,
    required this.vipType,
    required this.vipStatus,
  });
  late final int type;
  late final int status;
  late final int dueDate;
  late final int vipPayType;
  late final int themeType;
  late final Label label;
  late final int avatarSubscript;
  late final String nicknameColor;
  late final int role;
  late final String avatarSubscriptUrl;
  late final int tvVipStatus;
  late final int tvVipPayType;
  late final int tvDueDate;
  late final int vipType;
  late final int vipStatus;

  Vip.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    status = json['status'];
    dueDate = json['due_date'];
    vipPayType = json['vip_pay_type'];
    themeType = json['theme_type'];
    label = Label.fromJson(json['label']);
    avatarSubscript = json['avatar_subscript'];
    nicknameColor = json['nickname_color'];
    role = json['role'];
    avatarSubscriptUrl = json['avatar_subscript_url'];
    tvVipStatus = json['tv_vip_status'];
    tvVipPayType = json['tv_vip_pay_type'];
    tvDueDate = json['tv_due_date'];
    vipType = json['vipType'];
    vipStatus = json['vipStatus'];
  }
}

class Label {
  Label({
    required this.path,
    required this.text,
    required this.labelTheme,
    required this.textColor,
    required this.bgStyle,
    required this.bgColor,
    required this.borderColor,
    required this.useImgLabel,
    required this.imgLabelUriHans,
    required this.imgLabelUriHant,
    required this.imgLabelUriHansStatic,
    required this.imgLabelUriHantStatic,
  });
  late final String path;
  late final String text;
  late final String labelTheme;
  late final String textColor;
  late final int bgStyle;
  late final String bgColor;
  late final String borderColor;
  late final bool useImgLabel;
  late final String imgLabelUriHans;
  late final String imgLabelUriHant;
  late final String imgLabelUriHansStatic;
  late final String imgLabelUriHantStatic;

  Label.fromJson(Map<String, dynamic> json) {
    path = json['path'];
    text = json['text'];
    labelTheme = json['label_theme'];
    textColor = json['text_color'];
    bgStyle = json['bg_style'];
    bgColor = json['bg_color'];
    borderColor = json['border_color'];
    useImgLabel = json['use_img_label'];
    imgLabelUriHans = json['img_label_uri_hans'];
    imgLabelUriHant = json['img_label_uri_hant'];
    imgLabelUriHansStatic = json['img_label_uri_hans_static'];
    imgLabelUriHantStatic = json['img_label_uri_hant_static'];
  }
}
