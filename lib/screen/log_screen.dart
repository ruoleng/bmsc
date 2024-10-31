import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../util/logger.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getLevelColor(Level level) {
    if (level == Level.SEVERE) {
      return Colors.red;
    } else if (level == Level.WARNING) {
      return Colors.orange;
    } else if (level == Level.INFO) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          Switch(
            value: LoggerUtils.isLoggingEnabled,
            onChanged: (value) async {
              await LoggerUtils.setLoggingEnabled(value);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清空日志'),
                  content: const Text('确定要清空所有日志吗？'),
                  actions: [
                    TextButton(
                      child: const Text('取消'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    FilledButton(
                      child: const Text('确定'),
                      onPressed: () {
                        LoggerUtils.clear();
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<LogRecord>(
        stream: LoggerUtils.logStream,
        builder: (context, _) {
          final logs = LoggerUtils.logs;

          return ListView.builder(
            controller: _scrollController,
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                dense: true,
                title: Text(
                  '[${log.time.toString().substring(5, 19)}] [${log.loggerName}] ${log.message}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _getLevelColor(log.level),
                  ),
                ),
                subtitle: log.error != null || log.stackTrace != null
                    ? Text(
                        '${log.error ?? ''}\n${log.stackTrace ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
