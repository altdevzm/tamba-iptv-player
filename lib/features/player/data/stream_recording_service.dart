import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/persistence/database_provider.dart';

class RecordingState {
  final bool isRecording;
  final String? streamTitle;
  final String? filePath;
  final int durationSeconds;
  final int bytesWritten;

  const RecordingState({
    this.isRecording = false,
    this.streamTitle,
    this.filePath,
    this.durationSeconds = 0,
    this.bytesWritten = 0,
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (bytesWritten < 1024 * 1024) {
      return '${(bytesWritten / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytesWritten / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class StreamRecordingNotifier extends StateNotifier<RecordingState> {
  final Dio _dio;
  CancelToken? _cancelToken;
  Timer? _timer;
  IOSink? _sink;

  StreamRecordingNotifier(this._dio) : super(const RecordingState());

  Future<String?> startRecording(String streamUrl, String title) async {
    if (state.isRecording) return null;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(p.join(docsDir.path, 'Recordings'));
      if (!recordingsDir.existsSync()) {
        recordingsDir.createSync(recursive: true);
      }

      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '_').replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(recordingsDir.path, '${safeTitle}_$timestamp.ts');
      final file = File(filePath);
      _sink = file.openWrite();

      _cancelToken = CancelToken();
      int totalBytes = 0;
      int seconds = 0;

      state = RecordingState(
        isRecording: true,
        streamTitle: title,
        filePath: filePath,
        durationSeconds: 0,
        bytesWritten: 0,
      );

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.isRecording) {
          seconds++;
          state = RecordingState(
            isRecording: true,
            streamTitle: title,
            filePath: filePath,
            durationSeconds: seconds,
            bytesWritten: totalBytes,
          );
        }
      });

      // Stream data from live source directly into file sink
      _dio.get<ResponseBody>(
        streamUrl,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      ).then((res) {
        final stream = res.data?.stream;
        if (stream != null) {
          stream.listen(
            (chunk) {
              totalBytes += chunk.length;
              _sink?.add(chunk);
            },
            onDone: () => stopRecording(),
            onError: (_) => stopRecording(),
            cancelOnError: true,
          );
        }
      }).catchError((_) {
        stopRecording();
      });

      return filePath;
    } catch (_) {
      stopRecording();
      return null;
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    _timer?.cancel();
    _timer = null;
    _cancelToken?.cancel();
    _cancelToken = null;

    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;

    state = RecordingState(
      isRecording: false,
      streamTitle: state.streamTitle,
      filePath: state.filePath,
      durationSeconds: state.durationSeconds,
      bytesWritten: state.bytesWritten,
    );
  }

  @override
  void dispose() {
    stopRecording();
    super.dispose();
  }
}

final streamRecordingProvider = StateNotifierProvider<StreamRecordingNotifier, RecordingState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StreamRecordingNotifier(apiClient.dio);
});

