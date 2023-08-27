String stripHtmlIfNeeded(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
}

String unit(int cnt) {
  if (cnt >= 10000) {
    return "${cnt ~/ 10000}.${cnt % 10000 ~/ 1000}w";
  } else {
    return "$cnt";
  }
}

String time(int tar, int cur) {
  final curTime = DateTime.fromMicrosecondsSinceEpoch(cur);
  final tarTime = DateTime.fromMicrosecondsSinceEpoch(tar);
  int delta = (cur - tar) ~/ 1000000;
  if (curTime.day == tarTime.day) {
    if (delta > 3600) {
      return "${delta ~/ 3600} 小时前";
    }
    if (delta > 60) {
      return "${delta / 60} 分钟前";
    } else {
      return "$delta 秒前";
    }
  } else {
    String hour = tarTime.hour.toString().padLeft(2, '0');
    String min = tarTime.minute.toString().padLeft(2, '0');
    return "${delta <= 3600 * 24 ? "昨天" : "${tarTime.month}-${tarTime.day}"} $hour:$min";
  }
}
