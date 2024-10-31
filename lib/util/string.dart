String stripHtmlIfNeeded(String text) {
  return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
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
  if (time.year == today.year &&
      time.month == today.month &&
      time.day == today.day) {
    return "今天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  } else if (time.year == yesterday.year &&
      time.month == yesterday.month &&
      time.day == yesterday.day) {
    return "昨天 ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  } else {
    return "${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}

bool containsSubarrayKMP(List<String> mainList, List<String> subList) {
  if (subList.isEmpty) return true;
  if (subList.length > mainList.length) return false;

  List<int> lps = _buildLPS(subList);
  int i = 0, j = 0;

  while (i < mainList.length) {
    if (mainList[i] == subList[j]) {
      i++;
      j++;
      if (j == subList.length) {
        return true;
      }
    } else {
      if (j != 0) {
        j = lps[j - 1];
      } else {
        i++;
      }
    }
  }

  return false;
}

List<int> _buildLPS(List<String> pattern) {
  List<int> lps = List.filled(pattern.length, 0);
  int length = 0, i = 1;

  while (i < pattern.length) {
    if (pattern[i] == pattern[length]) {
      length++;
      lps[i] = length;
      i++;
    } else {
      if (length != 0) {
        length = lps[length - 1];
      } else {
        lps[i] = 0;
        i++;
      }
    }
  }

  return lps;
}
