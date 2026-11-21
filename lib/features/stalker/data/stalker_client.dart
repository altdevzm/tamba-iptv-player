import 'dart:convert';
import 'package:dio/dio.dart';

class StalkerCredentials {
  final String serverUrl;
  final String macAddress; // e.g. "00:1A:79:XX:XX:XX"
  final String? token;

  const StalkerCredentials({
    required this.serverUrl,
    required this.macAddress,
    this.token,
  });

  StalkerCredentials copyWith({String? token}) {
    return StalkerCredentials(
      serverUrl: serverUrl,
      macAddress: macAddress,
      token: token ?? this.token,
    );
  }
}

class StalkerClient {
  final Dio _dio;
  final Map<String, String> _resolvedEndpointCache = {};

  StalkerClient(this._dio);

  static String normalizeMac(String mac) => mac.trim().toUpperCase();

  static String cleanBaseUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/c')) {
      u = u.substring(0, u.length - 2);
    }
    return u;
  }

  /// Extracts a direct `http://` or `https://` URL from a Stalker `cmd` string
  /// such as `"ffrt http://host/live/123"` or `"ffmpeg http://..."`.
  static String? extractDirectUrl(String? rawCmd) {
    if (rawCmd == null || rawCmd.trim().isEmpty) return null;
    final trimmed = rawCmd.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    for (final part in trimmed.split(RegExp(r'\s+'))) {
      if (part.startsWith('http://') || part.startsWith('https://')) {
        return part;
      }
    }
    return null;
  }

  List<String> _candidateEndpoints(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('.php')) {
      final withScheme =
          (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
              ? trimmed
              : 'http://$trimmed';
      return [withScheme];
    }
    final clean = cleanBaseUrl(baseUrl);
    return [
      '$clean/portal.php',
      '$clean/server/load.php',
      '$clean/stalker_portal/server/load.php',
      '$clean/c/portal.php',
    ];
  }

  String _resolveApiUrl(String baseUrl) {
    final clean = cleanBaseUrl(baseUrl);
    return _resolvedEndpointCache[clean] ?? _candidateEndpoints(baseUrl).first;
  }

  Options _buildOptions(StalkerCredentials creds) {
    final clean = cleanBaseUrl(creds.serverUrl);
    final mac = normalizeMac(creds.macAddress);
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
      'X-User-Agent': 'Model: MAG250; Link: Ethernet',
      'Referer': '$clean/c/',
      'Accept': '*/*',
      'Cookie': 'mac=${Uri.encodeComponent(mac)}; stb_lang=en; timezone=UTC',
    };
    if (creds.token != null && creds.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${creds.token}';
    }
    return Options(
      headers: headers,
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 20),
      followRedirects: true,
      maxRedirects: 5,
    );
  }

  /// Parses Stalker JSON even when the server sends `Content-Type: text/html`.
  Map<String, dynamic>? _decodeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _extractMapList(dynamic rawList) {
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Handshake to acquire Bearer session token and auto-discover the working
  /// Stalker/Ministra API endpoint (`/portal.php` vs `/server/load.php`).
  Future<String?> handshake(StalkerCredentials creds) async {
    final clean = cleanBaseUrl(creds.serverUrl);
    final mac = normalizeMac(creds.macAddress);
    final candidates = _candidateEndpoints(creds.serverUrl);

    for (final endpoint in candidates) {
      try {
        final res = await _dio.get<dynamic>(
          endpoint,
          queryParameters: {
            'type': 'stb',
            'action': 'handshake',
            'token': '',
            'mac': mac,
            'JsHttpRequest': '1-xml',
          },
          options: _buildOptions(creds),
        );

        final map = _decodeMap(res.data);
        if (map != null && map['js'] is Map) {
          _resolvedEndpointCache[clean] = endpoint;
          final token = map['js']['token']?.toString();
          if (token != null && token.isNotEmpty) {
            return token;
          }
          // Endpoint responded with valid Stalker JSON even without a token
          return null;
        }
      } catch (_) {
        // Try next candidate endpoint
      }
    }
    return null;
  }

  /// Get profile to verify and activate the STB session token.
  Future<Map<String, dynamic>?> getProfile(StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    try {
      final res = await _dio.get<dynamic>(
        url,
        queryParameters: {
          'type': 'stb',
          'action': 'get_profile',
          'hd': '1',
          'ver': 'ImageDescription: 0.2.18-r14-pub-250; ImageDate: Fri Jan 15 15:20:44 EET 2016; PORTAL version: 5.1.0;',
          'stb_type': 'MAG250',
          'JsHttpRequest': '1-xml',
        },
        options: _buildOptions(creds),
      );
      final map = _decodeMap(res.data);
      if (map != null && map['js'] is Map) {
        return Map<String, dynamic>.from(map['js'] as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch Live TV genres/categories
  Future<List<Map<String, dynamic>>> getLiveCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'type': 'itv',
        'action': 'get_genres',
        'JsHttpRequest': '1-xml',
      },
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null) {
      return _extractMapList(map['js']);
    }
    return [];
  }

  /// Fetch all Live TV channels
  Future<List<Map<String, dynamic>>> getLiveChannels(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'type': 'itv',
        'action': 'get_all_channels',
        'JsHttpRequest': '1-xml',
      },
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null && map['js'] is Map) {
      return _extractMapList(map['js']['data']);
    }
    if (map != null && map['js'] is List) {
      return _extractMapList(map['js']);
    }
    return [];
  }

  /// Fetch VOD categories
  Future<List<Map<String, dynamic>>> getVodCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'type': 'vod',
        'action': 'get_categories',
        'JsHttpRequest': '1-xml',
      },
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null) {
      return _extractMapList(map['js']);
    }
    return [];
  }

  /// Fetch VOD streams for a category
  Future<List<Map<String, dynamic>>> getVodStreams(
    StalkerCredentials creds, {
    String? categoryId,
    int page = 1,
  }) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final query = <String, dynamic>{
      'type': 'vod',
      'action': 'get_ordered_list',
      'p': page,
      'JsHttpRequest': '1-xml',
    };
    if (categoryId != null && categoryId != '*' && categoryId != 'all') {
      query['category'] = categoryId;
    }

    final res = await _dio.get<dynamic>(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null && map['js'] is Map) {
      return _extractMapList(map['js']['data']);
    }
    return [];
  }

  /// Fetch Series categories
  Future<List<Map<String, dynamic>>> getSeriesCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'type': 'series',
        'action': 'get_categories',
        'JsHttpRequest': '1-xml',
      },
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null) {
      return _extractMapList(map['js']);
    }
    return [];
  }

  /// Fetch Series streams
  Future<List<Map<String, dynamic>>> getSeriesStreams(
    StalkerCredentials creds, {
    String? categoryId,
    int page = 1,
  }) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final query = <String, dynamic>{
      'type': 'series',
      'action': 'get_ordered_list',
      'p': page,
      'JsHttpRequest': '1-xml',
    };
    if (categoryId != null && categoryId != '*' && categoryId != 'all') {
      query['category'] = categoryId;
    }

    final res = await _dio.get<dynamic>(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );
    final map = _decodeMap(res.data);
    if (map != null && map['js'] is Map) {
      return _extractMapList(map['js']['data']);
    }
    return [];
  }

  /// Fetch episodes/seasons for a specific series in Stalker portal
  Future<List<Map<String, dynamic>>> getSeriesEpisodes(
    StalkerCredentials creds,
    String seriesId, {
    int? season,
  }) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final query = <String, dynamic>{
      'type': 'series',
      'action': 'get_ordered_list',
      'movie_id': seriesId,
      'JsHttpRequest': '1-xml',
    };
    if (season != null) {
      query['season'] = season;
    }

    final res = await _dio.get<dynamic>(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );

    final map = _decodeMap(res.data);
    if (map != null) {
      final js = map['js'];
      if (js is List) {
        return _extractMapList(js);
      } else if (js is Map && js['data'] is List) {
        return _extractMapList(js['data']);
      }
    }
    return [];
  }

  /// Resolves the actual streaming link via create_link endpoint
  Future<String?> createLink(
    StalkerCredentials creds, {
    required String type, // 'itv' or 'vod'
    required String cmd,
  }) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get<dynamic>(
      url,
      queryParameters: {
        'type': type,
        'action': 'create_link',
        'cmd': cmd,
        'JsHttpRequest': '1-xml',
      },
      options: _buildOptions(creds),
    );

    final map = _decodeMap(res.data);
    if (map != null && map['js'] is Map) {
      final js = Map<String, dynamic>.from(map['js'] as Map);
      final rawCmd = js['cmd']?.toString();
      final direct = extractDirectUrl(rawCmd);
      if (direct != null) return direct;
      if (rawCmd != null && rawCmd.isNotEmpty) return rawCmd;
    }
    return extractDirectUrl(cmd);
  }
}

