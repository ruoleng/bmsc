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

String time(int t) {
  final time = DateTime.fromMicrosecondsSinceEpoch(t);
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  if (time.year == today.year && time.month == today.month && time.day == today.day) {
    return "今天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  } else if (time.year == yesterday.year && time.month == yesterday.month && time.day == yesterday.day) {
    return "昨天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  } else {
    return "${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}

