import 'package:bmsc/util/logger.dart';
import 'package:bmsc/globals.dart' as globals;
import 'dart:convert';
import 'package:crypto/crypto.dart';

final _logger = LoggerUtils.getLogger('Crypto');

  String _getMixinKey(String rawWbiKey) {
    const mixinKeyEncTab = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43,
        5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 
        16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56,
        59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    ];

    return mixinKeyEncTab.map((e) => rawWbiKey[e]).join('').substring(0, 32);
  }

  Future<Map<String, dynamic>?> encodeParams(
      Map<String, dynamic> params) async {
    final rawWbiKey = await globals.api.getRawWbiKey();
    if (rawWbiKey == null) return null;
    final mixinKey = _getMixinKey(rawWbiKey);
    final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    params['wts'] = wts.toString();
    params = Map.fromEntries(
        params.entries.map((e) => MapEntry(e.key, e.value.toString())).toList()
          ..sort((a, b) => a.key.compareTo(b.key)));
    final query = Uri(queryParameters: params).query;
    final encryptedQuery = query + mixinKey;
    final wRid = md5.convert(utf8.encode(encryptedQuery)).toString();
    _logger.info('encoded params with w_rid and wts');
    return {
      ...params,
      'w_rid': wRid,
    };
  }