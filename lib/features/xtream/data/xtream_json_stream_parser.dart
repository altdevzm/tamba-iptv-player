import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Constant-memory O(1) RAM streaming downloader + JSON object-by-object parser
/// for large Xtream Codes endpoints (`get_live_streams`, `get_vod_streams`,
/// `get_series`) that can exceed 100–250 MB (200k+ items) and trigger Android
/// TV LMKD out-of-memory kills when decoded all at once via `Dio`/`jsonDecode`.
class XtreamJsonStreamParser {
  /// Downloads [uri] directly to a temporary file on disk using [HttpClient]
  /// with constant memory and real download progress callbacks.
  static Future<File> downloadToTempFile(
    Uri uri, {
    required String tempTag,
    String userAgent = 'IPTVSmartersPro/1.0.0 (Linux; Android) VLC/3.0.18',
    String? referer,
    void Function(String status)? onProgress,
    String progressPrefix = 'Downloading',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeTag = tempTag.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final tempFile = File(p.join(tempDir.path, 'xtream_$safeTag.json.tmp'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..idleTimeout = const Duration(minutes: 2)
      ..autoUncompress = true
      ..badCertificateCallback = (_, __, ___) => true;

    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 6;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json, */*');
      if (referer != null && referer.isNotEmpty) {
        request.headers.set(HttpHeaders.refererHeader, referer);
      }

      final response = await request.close().timeout(
            const Duration(minutes: 3),
          );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HttpException(
          'Authentication failed (HTTP ${response.statusCode}). Check credentials or subscription.',
          uri: uri,
        );
      }
      if (response.statusCode >= 400) {
        throw HttpException(
          'Server returned HTTP ${response.statusCode} while $progressPrefix.',
          uri: uri,
        );
      }

      final totalBytes = response.contentLength;
      sink = tempFile.openWrite();
      var received = 0;
      var lastProgressMs = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastProgressMs >= 250) {
          lastProgressMs = now;
          final mb = (received / (1024 * 1024)).toStringAsFixed(1);
          if (totalBytes > 0) {
            final pct = ((received / totalBytes) * 100).clamp(0, 100).round();
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            onProgress?.call('$progressPrefix... $pct% ($mb / $totalMb MB)');
          } else {
            onProgress?.call('$progressPrefix... $mb MB');
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      return tempFile;
    } catch (e) {
      try {
        await sink?.close();
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Streams a JSON file containing either:
  /// - A JSON array of objects: `[{...}, {...}, ...]`
  /// - An Xtream associative object of objects: `{"0": {...}, "1": {...}}`
  ///
  /// Yields each item one [Map<String, dynamic>] at a time in O(1) RAM without
  /// ever loading the entire JSON string or full decoded list into memory.
  static Stream<Map<String, dynamic>> streamObjectsFromFile(File file) {
    final byteStream = file.openRead();
    return streamObjectsFromByteStream(byteStream);
  }

  /// Streams decoded top-level item objects from any UTF-8 [byteStream].
  static Stream<Map<String, dynamic>> streamObjectsFromByteStream(
    Stream<List<int>> byteStream,
  ) async* {
    final utf8Stream =
        byteStream.transform(const Utf8Decoder(allowMalformed: true));

    // Root container detection:
    // - If first non-whitespace char is '[', items are objects at braceDepth == 1.
    // - If first non-whitespace char is '{', items are nested objects at braceDepth == 2.
    int? targetItemDepth;
    var braceDepth = 0;
    var inString = false;
    var escaped = false;
    StringBuffer? currentObj;

    await for (final chunk in utf8Stream) {
      for (var i = 0; i < chunk.length; i++) {
        final code = chunk.codeUnitAt(i);

        // Detect root container on first non-whitespace character
        if (targetItemDepth == null) {
          if (code == 0x20 ||
              code == 0x09 ||
              code == 0x0A ||
              code == 0x0D ||
              code == 0xFEFF) {
            continue;
          }
          if (code == 0x5B) {
            // '[' -> JSON array of objects
            targetItemDepth = 1;
            continue;
          } else if (code == 0x7B) {
            // '{' -> JSON map of objects (e.g. {"0": {...}})
            targetItemDepth = 2;
            braceDepth = 1;
            continue;
          } else {
            // Not a JSON array or object (e.g. "null", HTML error page, empty)
            return;
          }
        }

        if (currentObj != null) {
          currentObj.writeCharCode(code);
        }

        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (code == 0x5C) {
            // '\\'
            escaped = true;
          } else if (code == 0x22) {
            // '"'
            inString = false;
          }
          continue;
        }

        if (code == 0x22) {
          // '"'
          inString = true;
          continue;
        }

        if (code == 0x7B) {
          // '{'
          braceDepth++;
          if (braceDepth == targetItemDepth) {
            currentObj = StringBuffer('{');
          }
        } else if (code == 0x7D) {
          // '}'
          if (braceDepth == targetItemDepth && currentObj != null) {
            final rawJson = currentObj.toString();
            currentObj = null;
            try {
              final decoded = jsonDecode(rawJson);
              if (decoded is Map<String, dynamic>) {
                yield decoded;
              } else if (decoded is Map) {
                yield Map<String, dynamic>.from(decoded);
              }
            } catch (_) {
              // Skip individual malformed entry without crashing the sync
            }
          }
          braceDepth--;
          if (braceDepth < 0) braceDepth = 0;
        }
      }
    }
  }
}
