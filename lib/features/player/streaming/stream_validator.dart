import 'package:dio/dio.dart';

import 'streaming_models.dart';

/// Pre-playback stream validator & HLS master playlist rendition parser.
///
/// Validates URL syntax, checks HTTP availability/authentication where
/// supported, distinguishes failure causes, and detects genuine ABR renditions
/// without falsely claiming ABR for fixed-quality M3U/MPEG-TS streams.
class StreamValidator {
  final Dio? _dio;

  const StreamValidator([this._dio]);

  static const _supportedSchemes = {'http', 'https', 'rtsp', 'rtmp', 'rtmps', 'file'};

  /// Redacts host credentials, query tokens, and sensitive path segments from
  /// URLs before writing them to logs or diagnostics.
  static String redactUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) return '<invalid-url>';
    final host = uri.host.isNotEmpty ? uri.host : 'local';
    final ext = _extractExtension(uri.path);
    return '${uri.scheme}://$host/•••${ext.isNotEmpty ? '.$ext' : ''}';
  }

  static String _extractExtension(String path) {
    final lower = path.toLowerCase();
    for (final ext in ['m3u8', 'mpd', 'ts', 'mp4', 'mkv', 'avi', 'mov', 'flv']) {
      if (lower.endsWith('.$ext')) return ext;
    }
    return '';
  }

  /// Validates [url] before opening the player.
  ///
  /// For HTTP/HTTPS `.m3u8` manifests, fetches the manifest text (within a
  /// strict 3.5 s timeout) to detect expired tokens, 404s, and multi-rendition
  /// ABR variants. For continuous MPEG-TS/VOD HTTP streams, performs a quick
  /// `HEAD` check and gracefully proceeds if the provider rejects `HEAD` (405).
  Future<StreamValidationResult> validate(
    String rawUrl, {
    Map<String, String> headers = const {},
  }) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const StreamValidationResult.failed(
        failureKind: StreamFailureKind.invalidUrl,
        userMessage: 'Stream URL is empty.',
      );
    }

    // Local filesystem paths (offline downloads)
    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) {
      return const StreamValidationResult.valid(
        contentType: 'local/file',
        supportsAbr: false,
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !_supportedSchemes.contains(uri.scheme.toLowerCase()) ||
        (uri.scheme.startsWith('http') && uri.host.isEmpty)) {
      return const StreamValidationResult.failed(
        failureKind: StreamFailureKind.invalidUrl,
        userMessage: 'Invalid stream URL format.',
      );
    }

    // RTSP / RTMP cannot be probed via HTTP
    if (!uri.scheme.toLowerCase().startsWith('http') || _dio == null) {
      return const StreamValidationResult.valid(supportsAbr: false);
    }

    final lowerPath = uri.path.toLowerCase();
    final isHls = lowerPath.endsWith('.m3u8') || lowerPath.contains('.m3u8?');
    final isDash = lowerPath.endsWith('.mpd');

    try {
      if (isHls) {
        final res = await _dio.get<dynamic>(
          trimmed,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            sendTimeout: const Duration(milliseconds: 3000),
            receiveTimeout: const Duration(milliseconds: 3500),
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) => status != null && status < 600,
          ),
        );

        final status = res.statusCode ?? 200;
        final statusError = _classifyHttpStatus(status);
        if (statusError != null) return statusError;

        final contentType = res.headers.value('content-type') ?? '';
        final body = res.data?.toString() ?? '';
        if (body.trimLeft().startsWith('<html') ||
            body.trimLeft().startsWith('<!DOCTYPE')) {
          return StreamValidationResult.failed(
            failureKind: StreamFailureKind.streamUnavailable,
            userMessage:
                'Provider returned a web error page instead of an HLS playlist.',
            httpStatusCode: status,
            contentType: contentType,
          );
        }

        final renditions = parseHlsMasterRenditions(body, baseUri: uri);
        return StreamValidationResult.valid(
          httpStatusCode: status,
          contentType: contentType,
          supportsAbr: renditions.length > 1,
          renditions: renditions,
        );
      }

      // For DASH or continuous TS/MP4 streams, do a fast HEAD probe.
      final res = await _dio.head<dynamic>(
        trimmed,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(milliseconds: 2500),
          receiveTimeout: const Duration(milliseconds: 2500),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final status = res.statusCode ?? 200;
      // Many IPTV servers block HEAD (405/501) while GET streams play fine.
      if (status == 405 || status == 501) {
        return StreamValidationResult.valid(
          httpStatusCode: status,
          supportsAbr: isDash,
        );
      }

      final statusError = _classifyHttpStatus(status);
      if (statusError != null) return statusError;

      final contentType = res.headers.value('content-type') ?? '';
      if (contentType.toLowerCase().contains('text/html')) {
        return StreamValidationResult.failed(
          failureKind: StreamFailureKind.streamUnavailable,
          userMessage: 'Stream source returned an HTML page instead of video.',
          httpStatusCode: status,
          contentType: contentType,
        );
      }

      return StreamValidationResult.valid(
        httpStatusCode: status,
        contentType: contentType,
        supportsAbr: isDash,
      );
    } on DioException catch (e) {
      // If a provider times out on HEAD, don't falsely block continuous TS streams;
      // let the native player attempt streaming unless it's a clear DNS/network loss.
      if (e.type == DioExceptionType.connectionError) {
        return const StreamValidationResult.failed(
          failureKind: StreamFailureKind.networkError,
          userMessage:
              'Network error: unable to reach the streaming server. Check your internet connection.',
        );
      }
      return StreamValidationResult.valid(supportsAbr: isDash);
    } catch (_) {
      return StreamValidationResult.valid(supportsAbr: isDash);
    }
  }

  static StreamValidationResult? _classifyHttpStatus(int status) {
    if (status == 401 || status == 403) {
      return StreamValidationResult.failed(
        failureKind: StreamFailureKind.expiredOrUnauthorized,
        userMessage:
            'Stream access denied (HTTP $status). Your playlist token or subscription may have expired.',
        httpStatusCode: status,
      );
    }
    if (status == 404 || status == 410) {
      return StreamValidationResult.failed(
        failureKind: StreamFailureKind.streamUnavailable,
        userMessage:
            'Stream unavailable (HTTP $status). This channel or movie is currently offline.',
        httpStatusCode: status,
      );
    }
    if (status >= 500) {
      return StreamValidationResult.failed(
        failureKind: StreamFailureKind.streamUnavailable,
        userMessage:
            'Streaming server error (HTTP $status). The provider server is temporarily unavailable.',
        httpStatusCode: status,
      );
    }
    return null;
  }

  /// Parses `#EXT-X-STREAM-INF` entries from an HLS master playlist.
  /// Returns an empty list for single-rendition media playlists.
  static List<StreamRendition> parseHlsMasterRenditions(
    String manifest, {
    Uri? baseUri,
  }) {
    if (!manifest.contains('#EXT-X-STREAM-INF')) return const [];

    final lines =
        manifest.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final renditions = <StreamRendition>[];

    final bwRegex = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false);
    final resRegex = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false);
    final codecsRegex = RegExp(r'CODECS="([^"]+)"', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;

      final bwMatch = bwRegex.firstMatch(line);
      final bandwidth = int.tryParse(bwMatch?.group(1) ?? '') ?? 0;

      final resMatch = resRegex.firstMatch(line);
      final width = int.tryParse(resMatch?.group(1) ?? '');
      final height = int.tryParse(resMatch?.group(2) ?? '');
      final codecs = codecsRegex.firstMatch(line)?.group(1);

      // Find the next non-comment URI line
      String? variantUri;
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (next.isEmpty) continue;
        if (next.startsWith('#')) continue;
        variantUri = baseUri != null ? baseUri.resolve(next).toString() : next;
        i = j;
        break;
      }

      if (variantUri == null) continue;

      final mbps = bandwidth > 0
          ? '${(bandwidth / 1000000).toStringAsFixed(1)} Mbps'
          : '';
      final resLabel = height != null ? '${height}p' : 'Stream';
      final label = mbps.isNotEmpty ? '$resLabel • $mbps' : resLabel;

      renditions.add(
        StreamRendition(
          id: '${height ?? 0}_$bandwidth',
          label: label,
          bandwidthBps: bandwidth,
          width: width,
          height: height,
          codecs: codecs,
          uri: variantUri,
        ),
      );
    }

    // Sort highest quality first, deduplicate identical IDs
    renditions.sort((a, b) => b.bandwidthBps.compareTo(a.bandwidthBps));
    final seen = <String>{};
    return renditions.where((r) => seen.add(r.id)).toList();
  }

  /// Classifies a raw player engine error string into a [StreamFailureKind].
  static StreamFailureKind classifyPlayerError(String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('forbidden')) {
      return StreamFailureKind.expiredOrUnauthorized;
    }
    if (lower.contains('404') ||
        lower.contains('410') ||
        lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('server returned')) {
      return StreamFailureKind.streamUnavailable;
    }
    if (lower.contains('unsupported') ||
        lower.contains('could not recognize') ||
        lower.contains('no video') ||
        lower.contains('invalid data found') ||
        lower.contains('unknown format')) {
      return StreamFailureKind.unsupportedFormat;
    }
    if (lower.contains('codec') ||
        lower.contains('decoder') ||
        lower.contains('mediacodec') ||
        lower.contains('hwdec')) {
      return StreamFailureKind.decoderError;
    }
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('resolve') ||
        lower.contains('eof')) {
      return StreamFailureKind.networkError;
    }
    return StreamFailureKind.streamUnavailable;
  }
}
