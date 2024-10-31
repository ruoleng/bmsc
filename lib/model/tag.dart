class TagResult {
  int? code;
  String? message;
  int? ttl;
  List<Data>? data;

  TagResult({this.code, this.message, this.ttl, this.data});

  TagResult.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    ttl = json['ttl'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = this.code;
    data['message'] = this.message;
    data['ttl'] = this.ttl;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  int? tagId;
  String? tagName;
  String? cover;
  String? headCover;
  String? content;
  String? shortContent;

  Data({
    this.tagId,
    this.tagName,
    this.cover,
    this.headCover,
    this.content,
    this.shortContent,
  });

  Data.fromJson(Map<String, dynamic> json) {
    tagId = json['tag_id'];
    tagName = json['tag_name'];
    cover = json['cover'];
    headCover = json['head_cover'];
    content = json['content'];
    shortContent = json['short_content'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['tag_id'] = this.tagId;
    data['tag_name'] = this.tagName;
    data['cover'] = this.cover;
    data['head_cover'] = this.headCover;
    data['content'] = this.content;
    data['short_content'] = this.shortContent;
    return data;
  }
}
