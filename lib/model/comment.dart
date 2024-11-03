class CommentData {
  final PageInfo? page;
  final Cursor? cursor;
  final List<ItemInfo>? replies;

  CommentData({
    required this.page,
    required this.cursor,
    this.replies,
  });

  factory CommentData.fromJson(Map<String, dynamic> json) {
    return CommentData(
      cursor: json['cursor'] != null ? Cursor.fromJson(json['cursor']) : null,
      page: json['page'] != null ? PageInfo.fromJson(json['page']) : null,
      replies: (json['replies'] as List?)?.map((e) => ItemInfo.fromJson(e)).toList(),
    );
  }
}

class PageInfo {
  final int num;
  final int size;
  final int count;

  PageInfo({
    required this.num,
    required this.size,
    required this.count,
  });

  factory PageInfo.fromJson(Map<String, dynamic> json) {
    return PageInfo(
      num: json['num'] ?? 0,
      size: json['size'] ?? 0,
      count: json['count'] ?? 0,
    );
  }
}

class Cursor {
  final bool isBegin;
  final bool isEnd;
  final int prev;
  final int next;
  final int allCount;

  Cursor({
    required this.isBegin,
    required this.isEnd,
    required this.prev,
    required this.next,
    required this.allCount,
  });

  factory Cursor.fromJson(Map<String, dynamic> json) {
    return Cursor(
      isBegin: json['is_begin'] ?? false,
      isEnd: json['is_end'] ?? false,
      prev: json['prev'] ?? 0,
      next: json['next'] ?? 0,
      allCount: json['all_count'] ?? 0,
    );
  }
}

class ItemInfo {
  final int ctime;
  final int like;
  final int action;
  final int oid;
  final int root;
  final int count;
  final int rpid;
  final MemberInfo member;
  final ContentInfo? content;
  final List<ItemInfo>? replies;

  ItemInfo({
    required this.ctime,
    required this.like,
    required this.oid,
    required this.root,
    required this.count,
    required this.action,
    required this.member,
    required this.content,
    this.replies,
    required this.rpid,
  });

  factory ItemInfo.fromJson(Map<String, dynamic> json) {
    return ItemInfo(
      ctime: json['ctime'] ?? 0,
      rpid: json['rpid'] ?? 0,
      like: json['like'] ?? 0,
      action: json['action'] ?? 0,
      oid: json['oid'] ?? 0,
      root: json['root'] ?? 0,
      count: json['count'] ?? 0,
      member: MemberInfo.fromJson(json['member']),
      content: ContentInfo.fromJson(json['content']),
      replies: (json['replies'] as List?)?.map((e) => ItemInfo.fromJson(e)).toList(),
    );
  }
}

class MemberInfo {
  final String mid;
  final String uname;
  final String avatar;

  MemberInfo({
    required this.mid,
    required this.uname,
    required this.avatar,
  });

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      mid: json['mid'] ?? '',
      uname: json['uname'] ?? '',
      avatar: json['avatar'] ?? '',
    );
  }
}

class ContentInfo {
  final String message;

  ContentInfo({required this.message});

  factory ContentInfo.fromJson(Map<String, dynamic> json) {
    return ContentInfo(
      message: json['message'] ?? '',
    );
  }
}
