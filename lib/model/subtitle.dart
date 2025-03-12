class BilibiliSubtitle {
  final int from; // 字幕开始时间（毫秒）
  final int to; // 字幕结束时间（毫秒）
  final String content; // 字幕内容
  final int location; // 字幕位置（1: 底部, 2: 顶部）

  BilibiliSubtitle({
    required this.from,
    required this.to,
    required this.content,
    this.location = 1,
  });

  factory BilibiliSubtitle.fromJson(Map<String, dynamic> json) {
    return BilibiliSubtitle(
      from: ((json['from'] as double) * 1000).toInt(),
      to: ((json['to'] as double) * 1000).toInt(),
      content: json['content'] as String,
      location: json['location'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'content': content,
      'location': location,
    };
  }
}
