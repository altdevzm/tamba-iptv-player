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

  StalkerClient(this._dio);

  String _cleanUrl(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/c')) {
      u = u.substring(0, u.length - 2);
    }
    return u;
  }

  String _resolveApiUrl(String baseUrl) {
    final clean = _cleanUrl(baseUrl);
    if (clean.endsWith('.php')) return clean;
    return '$clean/server/load.php';
  }

  Options _buildOptions(StalkerCredentials creds) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
      'X-User-Agent': 'Model: MAG250; Link: Ethernet',
      'Cookie': 'mac=${creds.macAddress}; stb_lang=en; timezone=UTC',
    };
    if (creds.token != null && creds.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${creds.token}';
    }
    return Options(headers: headers);
  }

  /// Handshake to acquire Bearer session token
  Future<String?> handshake(StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    try {
      final res = await _dio.get(
        url,
        queryParameters: {
          'type': 'stb',
          'action': 'handshake',
          'token': '',
          'mac': creds.macAddress,
        },
        options: _buildOptions(creds),
      );

      if (res.data is Map && res.data['js'] is Map) {
        return res.data['js']['token'] as String?;
      }
      return null;
    } catch (_) {
      // Fallback for simple portals without handshake
      return null;
    }
  }

  /// Get profile to verify activation
  Future<Map<String, dynamic>?> getProfile(StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': 'stb',
        'action': 'get_profile',
      },
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is Map) {
      return res.data['js'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Fetch Live TV genres/categories
  Future<List<Map<String, dynamic>>> getLiveCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': 'itv',
        'action': 'get_genres',
      },
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is List) {
      return (res.data['js'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Fetch all Live TV channels
  Future<List<Map<String, dynamic>>> getLiveChannels(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': 'itv',
        'action': 'get_all_channels',
      },
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is Map && res.data['js']['data'] is List) {
      return (res.data['js']['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Fetch VOD categories
  Future<List<Map<String, dynamic>>> getVodCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': 'vod',
        'action': 'get_categories',
      },
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is List) {
      return (res.data['js'] as List).cast<Map<String, dynamic>>();
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
    };
    if (categoryId != null && categoryId != '*' && categoryId != 'all') {
      query['category'] = categoryId;
    }

    final res = await _dio.get(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is Map && res.data['js']['data'] is List) {
      return (res.data['js']['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Fetch Series categories
  Future<List<Map<String, dynamic>>> getSeriesCategories(
      StalkerCredentials creds) async {
    final url = _resolveApiUrl(creds.serverUrl);
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': 'series',
        'action': 'get_categories',
      },
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is List) {
      return (res.data['js'] as List).cast<Map<String, dynamic>>();
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
    };
    if (categoryId != null && categoryId != '*' && categoryId != 'all') {
      query['category'] = categoryId;
    }

    final res = await _dio.get(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );
    if (res.data is Map && res.data['js'] is Map && res.data['js']['data'] is List) {
      return (res.data['js']['data'] as List).cast<Map<String, dynamic>>();
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
    };
    if (season != null) {
      query['season'] = season;
    }

    final res = await _dio.get(
      url,
      queryParameters: query,
      options: _buildOptions(creds),
    );

    if (res.data is Map) {
      final js = res.data['js'];
      if (js is List) {
        return js.cast<Map<String, dynamic>>();
      } else if (js is Map && js['data'] is List) {
        return (js['data'] as List).cast<Map<String, dynamic>>();
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
    final res = await _dio.get(
      url,
      queryParameters: {
        'type': type,
        'action': 'create_link',
        'cmd': cmd,
      },
      options: _buildOptions(creds),
    );

    if (res.data is Map && res.data['js'] is Map) {
      final js = res.data['js'] as Map<String, dynamic>;
      final rawCmd = js['cmd'] as String?;
      if (rawCmd != null) {
        // Many Stalker portals return "ffmpeg http://..." or "auto http://..."
        final parts = rawCmd.split(' ');
        for (final p in parts) {
          if (p.startsWith('http://') || p.startsWith('https://')) {
            return p;
          }
        }
        return rawCmd;
      }
    }
    return null;
  }
}

