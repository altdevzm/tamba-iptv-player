import 'dart:convert';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Credentials value object
// ---------------------------------------------------------------------------

class XtreamCredentials {
  /// Normalized server URL – no trailing slash, always has a scheme.
  final String serverUrl;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  /// Returns a new [XtreamCredentials] with [serverUrl] normalised.
  factory XtreamCredentials.normalized({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    var url = serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // Strip trailing endpoints if the user entered player_api.php or get.php
    url = url.replaceAll(RegExp(r'\/(?:get|player_api|panel_api)\.php$', caseSensitive: false), '');
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return XtreamCredentials(
      serverUrl: url,
      username: username.trim(),
      password: password.trim(),
    );
  }
}

// ---------------------------------------------------------------------------
// Typed exception
// ---------------------------------------------------------------------------

class XtreamApiException implements Exception {
  final String message;
  final int? statusCode;

  XtreamApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'XtreamApiException(statusCode: $statusCode): $message';
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

class XtreamClient {
  final Dio _dio;

  XtreamClient(Dio dio) : _dio = dio;

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Builds a player_api.php URL, hiding the password from logs by keeping
  /// query params in [queryParameters] rather than embedded in the URL string.
  Uri _playerApiUri(
    XtreamCredentials creds, {
    required Map<String, String> extra,
  }) {
    var rawUrl = creds.serverUrl.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'http://$rawUrl';
    }
    rawUrl = rawUrl.replaceAll(RegExp(r'\/(?:get|player_api|panel_api)\.php$', caseSensitive: false), '');
    while (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    final base = Uri.parse('$rawUrl/player_api.php');
    return base.replace(queryParameters: {
      'username': creds.username.trim(),
      'password': creds.password.trim(),
      ...extra,
    });
  }

  /// Scrubs the password from a raw URL string so it is never logged.
  String sanitizeUrl(String url, XtreamCredentials creds) =>
      url.replaceAll(creds.password, '******');

  Future<Response<dynamic>> _get(Uri uri) => _dio.getUri(uri);

  // ── Account ─────────────────────────────────────────────────────────────

  /// Fetches account info, falling back to the no-action endpoint on 4xx.
  Future<Map<String, dynamic>> getAccountInfo(XtreamCredentials creds) async {
    final primary = _playerApiUri(
      creds,
      extra: {'action': 'get_account_info'},
    );

    try {
      final resp = await _get(primary);
      return _toMap(resp.data, 'getAccountInfo');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        // Fallback: bare credentials, no action parameter.
        final fallback = _playerApiUri(creds, extra: {});
        try {
          final resp = await _get(fallback);
          return _toMap(resp.data, 'getAccountInfo (fallback)');
        } on DioException catch (e2) {
          throw _wrap(e2, creds, 'getAccountInfo (fallback)');
        } catch (e2) {
          throw XtreamApiException(
            'getAccountInfo (fallback) failed: ${_safeMsgOf(e2, creds)}',
          );
        }
      }
      throw _wrap(e, creds, 'getAccountInfo');
    } catch (e) {
      throw XtreamApiException(
        'getAccountInfo failed: ${_safeMsgOf(e, creds)}',
      );
    }
  }

  // ── Categories ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLiveCategories(
    XtreamCredentials creds,
  ) =>
      _fetchList(creds, action: 'get_live_categories', label: 'getLiveCategories');

  Future<List<Map<String, dynamic>>> getVodCategories(
    XtreamCredentials creds,
  ) =>
      _fetchList(creds, action: 'get_vod_categories', label: 'getVodCategories');

  Future<List<Map<String, dynamic>>> getSeriesCategories(
    XtreamCredentials creds,
  ) =>
      _fetchList(creds,
          action: 'get_series_categories', label: 'getSeriesCategories');

  // ── Streams ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLiveStreams(
    XtreamCredentials creds, {
    String? categoryId,
  }) =>
      _fetchList(
        creds,
        action: 'get_live_streams',
        label: 'getLiveStreams',
        extra: categoryId != null ? {'category_id': categoryId} : {},
      );

  Future<List<Map<String, dynamic>>> getVodStreams(
    XtreamCredentials creds, {
    String? categoryId,
  }) =>
      _fetchList(
        creds,
        action: 'get_vod_streams',
        label: 'getVodStreams',
        extra: categoryId != null ? {'category_id': categoryId} : {},
      );

  Future<List<Map<String, dynamic>>> getSeriesStreams(
    XtreamCredentials creds, {
    String? categoryId,
  }) =>
      _fetchList(
        creds,
        action: 'get_series',
        label: 'getSeriesStreams',
        extra: categoryId != null ? {'category_id': categoryId} : {},
      );

  // ── Detail endpoints ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getVodInfo(
    XtreamCredentials creds,
    String vodId,
  ) async {
    final uri = _playerApiUri(
      creds,
      extra: {'action': 'get_vod_info', 'vod_id': vodId},
    );
    return _fetchMap(uri, creds, label: 'getVodInfo');
  }

  Future<Map<String, dynamic>> getSeriesInfo(
    XtreamCredentials creds,
    String seriesId,
  ) async {
    final uri = _playerApiUri(
      creds,
      extra: {'action': 'get_series_info', 'series_id': seriesId},
    );
    return _fetchMap(uri, creds, label: 'getSeriesInfo');
  }

  Future<List<Map<String, dynamic>>> getShortEpg(
    XtreamCredentials creds,
    String streamId, {
    int limit = 4,
  }) =>
      _fetchList(
        creds,
        action: 'get_short_epg',
        label: 'getShortEpg',
        extra: {'stream_id': streamId, 'limit': limit.toString()},
      );

  // ── Stream URL builders ──────────────────────────────────────────────────

  String _cleanBaseUrl(String serverUrl) {
    var rawUrl = serverUrl.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'http://$rawUrl';
    }
    rawUrl = rawUrl.replaceAll(RegExp(r'\/(?:get|player_api|panel_api)\.php$', caseSensitive: false), '');
    while (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    return rawUrl;
  }

  String buildLiveStreamUrl(
    XtreamCredentials creds,
    String streamId, {
    String ext = 'ts',
  }) {
    final base = _cleanBaseUrl(creds.serverUrl);
    final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
    return '$base/live/${creds.username}/${creds.password}/$streamId.$cleanExt';
  }

  String buildVodStreamUrl(
    XtreamCredentials creds,
    String vodId,
    String containerExt,
  ) {
    final base = _cleanBaseUrl(creds.serverUrl);
    final cleanExt = containerExt.startsWith('.') ? containerExt.substring(1) : containerExt;
    return '$base/movie/${creds.username}/${creds.password}/$vodId.$cleanExt';
  }

  String buildSeriesStreamUrl(
    XtreamCredentials creds,
    String episodeId,
    String containerExt,
  ) {
    final base = _cleanBaseUrl(creds.serverUrl);
    final cleanExt = containerExt.startsWith('.') ? containerExt.substring(1) : containerExt;
    return '$base/series/${creds.username}/${creds.password}/$episodeId.$cleanExt';
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchList(
    XtreamCredentials creds, {
    required String action,
    required String label,
    Map<String, String> extra = const {},
  }) async {
    final uri = _playerApiUri(
      creds,
      extra: {'action': action, ...extra},
    );
    try {
      final resp = await _get(uri);
      return _toList(resp.data, label);
    } on DioException catch (e) {
      throw _wrap(e, creds, label);
    } catch (e) {
      throw XtreamApiException('$label failed: ${_safeMsgOf(e, creds)}');
    }
  }

  Future<Map<String, dynamic>> _fetchMap(
    Uri uri,
    XtreamCredentials creds, {
    required String label,
  }) async {
    try {
      final resp = await _get(uri);
      return _toMap(resp.data, label);
    } on DioException catch (e) {
      throw _wrap(e, creds, label);
    } catch (e) {
      throw XtreamApiException('$label failed: ${_safeMsgOf(e, creds)}');
    }
  }

  Map<String, dynamic> _toMap(dynamic data, String label) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return {};
      }
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List<Map<String, dynamic>> _toList(dynamic data, String label) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        throw XtreamApiException('$label returned invalid JSON: $e');
      }
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      if (data.isEmpty) return [];
      final error = data['error'];
      if (error != null) {
        throw XtreamApiException('$label failed: $error');
      }
      final rows = data.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (rows.isNotEmpty) return rows;
    }
    if (data == null) return [];
    throw XtreamApiException('$label returned an unexpected response');
  }

  XtreamApiException _wrap(
    DioException e,
    XtreamCredentials creds,
    String label,
  ) {
    final status = e.response?.statusCode;
    final safeMsg = _safeMsgOf(e, creds);
    return XtreamApiException(
      '$label failed: $safeMsg',
      statusCode: status,
    );
  }

  String _safeMsgOf(Object e, XtreamCredentials creds) {
    final raw = e.toString();
    return raw.replaceAll(creds.password, '******');
  }
}
