import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 单位为MB
  static Future<void> setCacheLimitSize(int size) async {
    final prefs = await instance;
    await prefs.setInt('cacheLimitSize', size);
  }

  /// 单位为MB
  static Future<int> getCacheLimitSize() async {
    final prefs = await instance;
    return prefs.getInt('cacheLimitSize') ?? 300;
  }

  static Future<bool> getReadFromClipboard() async {
    final prefs = await instance;
    return prefs.getBool('readFromClipboard') ?? true;
  }

  static Future<void> setReadFromClipboard(bool value) async {
    final prefs = await instance;
    await prefs.setBool('readFromClipboard', value);
  }
}
