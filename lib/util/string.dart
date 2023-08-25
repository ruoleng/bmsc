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
