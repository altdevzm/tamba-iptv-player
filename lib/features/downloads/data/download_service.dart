import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/persistence/database_provider.dart';

enum DownloadStatus { pending, downloading, paused, completed, failed }

class DownloadTask {
  final String id;
  final String title;
  final String url;
  final String? posterUrl;
  final String filePath;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final DownloadStatus status;
  final CancelToken? cancelToken;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    this.posterUrl,
    required this.filePath,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.pending,
    this.cancelToken,
  });

  DownloadTask copyWith({
    String? id,
    String? title,
    String? url,
    String? posterUrl,
    String? filePath,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    DownloadStatus? status,
    CancelToken? cancelToken,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      posterUrl: posterUrl ?? this.posterUrl,
      filePath: filePath ?? this.filePath,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final Dio _dio;

  DownloadNotifier(this._dio) : super([]);

  Future<void> startDownload({
    required String id,
    required String title,
    required String streamUrl,
    String? posterUrl,
    String? extension,
  }) async {
    // If already downloading or completed, ignore
    if (state.any((t) => t.id == id && t.status == DownloadStatus.completed)) {
      return;
    }

    final ext = extension ?? (streamUrl.contains('.mp4') ? 'mp4' : 'ts');
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(dir.path, 'downloads'));
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filePath = p.join(downloadDir.path, '${safeTitle}_$id.$ext');

    final cancelToken = CancelToken();

    final task = DownloadTask(
      id: id,
      title: title,
      url: streamUrl,
      posterUrl: posterUrl,
      filePath: filePath,
      status: DownloadStatus.downloading,
      cancelToken: cancelToken,
    );

    state = [...state.where((t) => t.id != id), task];

    try {
      await _dio.download(
        streamUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            _updateTask(id, (t) => t.copyWith(
                  progress: progress,
                  bytesDownloaded: received,
                  totalBytes: total,
                ));
          }
        },
      );

      _updateTask(id, (t) => t.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
          ));
    } catch (e) {
      if (cancelToken.isCancelled) {
        _updateTask(id, (t) => t.copyWith(status: DownloadStatus.paused));
      } else {
        _updateTask(id, (t) => t.copyWith(status: DownloadStatus.failed));
      }
    }
  }

  void pauseDownload(String id) {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      state[taskIndex].cancelToken?.cancel();
    }
  }

  Future<void> deleteDownload(String id) async {
    final task = state.firstWhere((t) => t.id == id, orElse: () => throw 'Not found');
    task.cancelToken?.cancel();

    final file = File(task.filePath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }

    state = state.where((t) => t.id != id).toList();
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    state = state.map((t) => t.id == id ? updater(t) : t).toList();
  }
}

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DownloadNotifier(apiClient.dio);
});

