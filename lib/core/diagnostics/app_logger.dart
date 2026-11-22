import 'package:flutter/foundation.dart';

/// Lightweight, credential-sanitizing diagnostic logger for Tamba IPTV.
///
/// Captures startup timing, memory-intensive operations, playlist sync
/// failures, database errors, player lifecycle errors, and unhandled
/// exceptions while strictly redacting URLs, passwords, and tokens.
class AppLogger {
  AppLogger._();

  static final Stopwatch _startupWatch = Stopwatch();
  static bool _startupCompleted = false;

  static final _urlWithQueryRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
  static final _secretParamRegex = RegExp(
    r'(password|pass|token|api_key|apikey|username|user)=[^&\s]+',
    caseSensitive: false,
  );

  static void markAppStart() {
    if (!_startupWatch.isRunning) {
      _startupWatch.start();
    }
  }

  static void markFirstFrameReady() {
    if (_startupCompleted) return;
    _startupCompleted = true;
    _startupWatch.stop();
    info('Startup', 'First frame ready in ${_startupWatch.elapsedMilliseconds}ms');
  }

  /// Strips query strings, credentials, and raw URLs so sensitive provider
  /// information is never written to device logs.
  static String sanitize(Object? input) {
    if (input == null) return '';
    var text = input.toString();
    text = text.replaceAllMapped(_urlWithQueryRegex, (match) {
      final raw = match.group(0) ?? '';
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.host.isEmpty) return '[redacted-url]';
      return '${uri.scheme}://${uri.host}/[redacted]';
    });
    text = text.replaceAllMapped(_secretParamRegex, (m) {
      final key = m.group(1) ?? 'param';
      return '$key=[redacted]';
    });
    return text;
  }

  static void info(String tag, String message) {
    debugPrint('[Tamba/$tag] ${sanitize(message)}');
  }

  static void warn(String tag, String message) {
    debugPrint('[Tamba/$tag][WARN] ${sanitize(message)}');
  }

  static void error(String tag, String message, [Object? err, StackTrace? st]) {
    final detail = err != null ? ' | ${sanitize(err)}' : '';
    debugPrint('[Tamba/$tag][ERROR] ${sanitize(message)}$detail');
    if (st != null && kDebugMode) {
      debugPrint(st.toString().split('\n').take(6).join('\n'));
    }
  }
}
