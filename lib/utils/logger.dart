import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class LoggerUtils {
  static Logger? _logger;

  static void init() {
    if (!kDebugMode) {
      return;
    }
    Logger.root.level = Level.ALL;

    Logger.root.onRecord.listen((record) {
      debugPrint(
          '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('Stack trace:\n${record.stackTrace}');
      }
    });
  }

  static Logger get logger {
    _logger ??= Logger('BMSC');
    return _logger!;
  }
}
