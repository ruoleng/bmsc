import 'package:dio/dio.dart';

enum DownloadStatus {
  failed,
  downloading,
  pending,
  paused,
  canceled,
  completed,
}

class DownloadTask {
  final String bvid;
  final int cid;

  String? targetPath;
  DownloadStatus status;
  double progress;
  String? error;
  CancelToken? cancelToken;

  DownloadTask({
    required this.bvid,
    required this.cid,
    this.targetPath,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'bvid': bvid,
        'cid': cid,
        'targetPath': targetPath,
        'status': status.index,
        'progress': progress,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        bvid: json['bvid'],
        cid: json['cid'],
        targetPath: json['targetPath'],
        status: DownloadStatus.values[json['status']],
        progress: json['progress'],
      );
}
