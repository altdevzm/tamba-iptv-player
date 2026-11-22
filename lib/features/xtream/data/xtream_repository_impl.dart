import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/persistence/app_database.dart';
import 'xtream_client.dart';
import 'xtream_json_stream_parser.dart';

/// Repository that imports or refreshes an Xtream Codes playlist into the
/// local Drift database safely using O(1) constant-RAM streaming so 200k–300k+
/// item Xtream catalogs never trigger Android TV OOM kills during login.
class XtreamRepositoryImpl {
  final AppDatabase _db;
  final XtreamClient _client;

  /// Prevents multiple simultaneous refresh operations for the same playlist.
  static final Set<String> _activeSyncs = <String>{};

  XtreamRepositoryImpl({
    required AppDatabase db,
    required XtreamClient client,
  })  : _db = db,
        _client = client;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Imports a brand-new Xtream playlist. Inserts rows and updates the
  /// playlist metadata on success.
  Future<void> importXtreamPlaylist(
    String playlistId,
    XtreamCredentials creds, {
    void Function(String status)? onProgress,
  }) =>
      _syncPlaylist(playlistId, creds, onProgress: onProgress);

  /// Re-syncs an existing playlist, upserting all rows safely without
  /// destroying the working playlist if the network or server fails.
  Future<void> refreshXtreamPlaylist(
    String playlistId,
    XtreamCredentials creds, {
    void Function(String status)? onProgress,
  }) =>
      _syncPlaylist(playlistId, creds, onProgress: onProgress);

  // ── Core streaming sync logic ─────────────────────────────────────────────

  Uri _buildActionUri(XtreamCredentials creds, String action) {
    var rawUrl = creds.serverUrl.trim();
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'http://$rawUrl';
    }
    rawUrl = rawUrl.replaceAll(
      RegExp(r'\/(?:get|player_api|panel_api)\.php$', caseSensitive: false),
      '',
    );
    while (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    return Uri.parse('$rawUrl/player_api.php').replace(queryParameters: {
      'username': creds.username.trim(),
      'password': creds.password.trim(),
      'action': action,
    });
  }

  Future<void> _syncPlaylist(
    String playlistId,
    XtreamCredentials creds, {
    void Function(String status)? onProgress,
  }) async {
    if (!_activeSyncs.add(playlistId)) {
      throw Exception('This playlist is already updating. Please wait.');
    }

    final sw = Stopwatch()..start();
    try {
      // 1. Validate URL & credentials before touching the database.
      final uri = Uri.tryParse(creds.serverUrl.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw Exception('Invalid Xtream server URL.');
      }

      onProgress?.call('Authenticating with Xtream server...');
      try {
        final info = await _client.getAccountInfo(creds);
        final userInfo = info['user_info'];
        if (userInfo is Map) {
          final auth = userInfo['auth'];
          if (auth == 0 || auth == '0' || auth == false) {
            throw Exception(
              'Invalid Xtream username or password. Please check your login details.',
            );
          }
          final status = userInfo['status']?.toString().toLowerCase();
          if (status == 'expired' || status == 'banned' || status == 'disabled') {
            throw Exception(
              'Xtream account is $status. Please contact your IPTV provider.',
            );
          }
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          throw Exception(
            'Authentication failed (HTTP $code). Check your username, password, or subscription.',
          );
        }
        // Some panels restrict get_account_info; proceed to fetch categories.
      } on XtreamApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          throw Exception(
            'Authentication failed (HTTP ${e.statusCode}). Check your credentials.',
          );
        }
        // Proceed if only get_account_info is restricted.
      }

      // 2. Fetch small category lists and upsert them safely.
      onProgress?.call('Loading categories (Live, Movies, Series)...');
      final liveCategories = await _safeFetchCategories(
        () => _client.getLiveCategories(creds),
        'live',
      );
      final vodCategories = await _safeFetchCategories(
        () => _client.getVodCategories(creds),
        'movies',
      );
      final seriesCategories = await _safeFetchCategories(
        () => _client.getSeriesCategories(creds),
        'series',
      );

      final categoryCompanions = <CategoriesTableCompanion>[
        ..._mapCategories(playlistId, liveCategories, 'live'),
        ..._mapCategories(playlistId, vodCategories, 'movies'),
        ..._mapCategories(playlistId, seriesCategories, 'series'),
      ];

      if (categoryCompanions.isNotEmpty) {
        await _db.transaction(() async {
          const catChunk = 500;
          for (var i = 0; i < categoryCompanions.length; i += catChunk) {
            final end = (i + catChunk < categoryCompanions.length)
                ? i + catChunk
                : categoryCompanions.length;
            await _db.batchInsertCategories(categoryCompanions.sublist(i, end));
          }
        });
      }

      // Reload persisted categories so we have their auto-incremented IDs.
      final savedLiveCats = await _db.getCategories(playlistId, 'live');
      final savedVodCats = await _db.getCategories(playlistId, 'movies');
      final savedSeriesCats = await _db.getCategories(playlistId, 'series');

      final liveCatByProviderId = {
        for (final c in savedLiveCats) c.providerId: c.id,
      };
      final vodCatByProviderId = {
        for (final c in savedVodCats) c.providerId: c.id,
      };
      final seriesCatByProviderId = {
        for (final c in savedSeriesCats) c.providerId: c.id,
      };

      // 3. Stream-download & stream-parse each catalog SEQUENTIALLY in O(1) RAM.
      //    Never holds full 100–200 MB JSON responses or decoded lists in memory!
      var totalSaved = 0;

      totalSaved += await _streamCatalog(
        playlistId: playlistId,
        uri: _buildActionUri(creds, 'get_live_streams'),
        tempTag: '${playlistId}_live',
        label: 'Live TV',
        onProgress: onProgress,
        mapRow: (s, idx) => _mapSingleLiveStream(
          playlistId,
          s,
          idx,
          liveCatByProviderId,
          creds,
        ),
      );

      totalSaved += await _streamCatalog(
        playlistId: playlistId,
        uri: _buildActionUri(creds, 'get_vod_streams'),
        tempTag: '${playlistId}_vod',
        label: 'Movies',
        onProgress: onProgress,
        mapRow: (s, idx) => _mapSingleVodStream(
          playlistId,
          s,
          idx,
          vodCatByProviderId,
          creds,
        ),
      );

      totalSaved += await _streamCatalog(
        playlistId: playlistId,
        uri: _buildActionUri(creds, 'get_series'),
        tempTag: '${playlistId}_series',
        label: 'Series',
        onProgress: onProgress,
        mapRow: (s, idx) => _mapSingleSeriesStream(
          playlistId,
          s,
          idx,
          seriesCatByProviderId,
          creds,
        ),
      );

      if (totalSaved == 0) {
        throw Exception(
          'Xtream server returned 0 channels. Check your credentials or server URL.',
        );
      }

      // 4. Update playlist metadata atomically.
      await (_db.update(_db.playlistsTable)
            ..where((t) => t.id.equals(playlistId)))
          .write(
        PlaylistsTableCompanion(
          channelCount: Value(totalSaved),
          lastUpdated: Value(DateTime.now()),
        ),
      );

      AppLogger.info(
        'XtreamSync',
        'Stream-synced $totalSaved items in ${sw.elapsedMilliseconds}ms',
      );
      onProgress?.call('Complete! Synced $totalSaved items.');
    } on HttpException catch (e, st) {
      AppLogger.error('XtreamSync', 'HTTP error during Xtream sync', e, st);
      throw Exception(e.message);
    } on SocketException catch (e, st) {
      AppLogger.error('XtreamSync', 'Network error during Xtream sync', e, st);
      throw Exception(
        'Could not reach Xtream server. Check your internet connection and retry.',
      );
    } on DioException catch (e, st) {
      AppLogger.error('XtreamSync', 'Dio error during Xtream sync', e, st);
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw Exception(
          'Authentication failed (HTTP $code). Check credentials or subscription.',
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Connection timed out reaching Xtream server. Existing playlist preserved.',
        );
      }
      throw Exception(
        'Could not reach Xtream server. Check your internet connection and retry.',
      );
    } catch (e, st) {
      AppLogger.error('XtreamSync', 'Xtream sync failed', e, st);
      rethrow;
    } finally {
      _activeSyncs.remove(playlistId);
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchCategories(
    Future<List<Map<String, dynamic>>> Function() fetcher,
    String label,
  ) async {
    try {
      return await fetcher();
    } catch (e) {
      AppLogger.warn('XtreamSync', 'Category fetch ($label) skipped: $e');
      return const [];
    }
  }

  /// Downloads one Xtream catalog endpoint to a temp file, streams JSON objects
  /// one by one, upserts in 1,000-row chunks inside short transactions, yields
  /// to the UI event loop between batches, and deletes the temp file immediately.
  Future<int> _streamCatalog({
    required String playlistId,
    required Uri uri,
    required String tempTag,
    required String label,
    required ContentItemsTableCompanion Function(
      Map<String, dynamic> row,
      int index,
    ) mapRow,
    void Function(String status)? onProgress,
  }) async {
    File? tempFile;
    try {
      onProgress?.call('Downloading $label...');
      tempFile = await XtreamJsonStreamParser.downloadToTempFile(
        uri,
        tempTag: tempTag,
        progressPrefix: 'Downloading $label',
        onProgress: onProgress,
      );

      onProgress?.call('Saving $label...');
      const batchSize = 1000;
      final batch = <ContentItemsTableCompanion>[];
      var count = 0;

      await for (final row
          in XtreamJsonStreamParser.streamObjectsFromFile(tempFile)) {
        batch.add(mapRow(row, count));
        count++;

        if (batch.length >= batchSize) {
          await _db.batchInsertContentItems(batch);
          batch.clear();
          onProgress?.call('Saving $label ($count items)...');
          // Yield to keep UI responsive & allow GC on low-RAM Smart TVs
          await Future<void>.delayed(Duration.zero);
        }
      }

      if (batch.isNotEmpty) {
        await _db.batchInsertContentItems(batch);
        batch.clear();
      }

      AppLogger.info('XtreamSync', 'Imported $count $label items');
      return count;
    } catch (e) {
      // Re-throw auth errors immediately; log non-fatal single-catalog errors
      if (e is HttpException &&
          (e.message.contains('401') || e.message.contains('403'))) {
        rethrow;
      }
      AppLogger.warn('XtreamSync', '$label catalog sync issue: $e');
      rethrow;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  // ── Mapping helpers (deduplicated per type + providerId) ──────────────────

  List<CategoriesTableCompanion> _mapCategories(
    String playlistId,
    List<Map<String, dynamic>> raw,
    String type,
  ) {
    final seen = <String>{};
    final result = <CategoriesTableCompanion>[];
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      final providerId = _str(c['category_id']) ?? '${type}_cat_$i';
      if (!seen.add(providerId)) continue;
      result.add(
        CategoriesTableCompanion(
          playlistId: Value(playlistId),
          name: Value(_str(c['category_name']) ?? _str(c['name']) ?? 'Unknown'),
          type: Value(type),
          providerId: Value(providerId),
        ),
      );
    }
    return result;
  }

  ContentItemsTableCompanion _mapSingleLiveStream(
    String playlistId,
    Map<String, dynamic> s,
    int idx,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    final providerId = _str(s['stream_id']) ?? 'live_$idx';
    final catProviderId = _str(s['category_id']);
    final categoryId =
        catProviderId != null ? catByProviderId[catProviderId] : null;
    final direct = _str(s['direct_source']);
    final streamUrl = (direct != null && direct.startsWith('http'))
        ? direct
        : _client.buildLiveStreamUrl(creds, providerId, ext: 'ts');

    return ContentItemsTableCompanion(
      playlistId: Value(playlistId),
      categoryId: Value(categoryId),
      title: Value(_str(s['name']) ?? 'Channel $providerId'),
      type: const Value('live'),
      providerId: Value(providerId),
      streamUrl: Value(streamUrl),
      containerExtension: const Value(null),
      posterUrl: Value(_str(s['stream_icon'])),
      rating: Value(_toDouble(s['rating'])),
      epgChannelId: Value(_str(s['epg_channel_id'])),
      tvArchive: Value(_toInt(s['tv_archive']) ?? 0),
      tvArchiveDuration: Value(_toInt(s['tv_archive_duration']) ?? 0),
      addedAt: Value(_unixToDateTime(s['added'])),
    );
  }

  ContentItemsTableCompanion _mapSingleVodStream(
    String playlistId,
    Map<String, dynamic> s,
    int idx,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    final providerId = _str(s['stream_id']) ?? 'movie_$idx';
    final containerExt = _str(s['container_extension']) ?? 'mp4';
    final catProviderId = _str(s['category_id']);
    final categoryId =
        catProviderId != null ? catByProviderId[catProviderId] : null;
    final direct = _str(s['direct_source']);
    final streamUrl = (direct != null && direct.startsWith('http'))
        ? direct
        : _client.buildVodStreamUrl(creds, providerId, containerExt);

    return ContentItemsTableCompanion(
      playlistId: Value(playlistId),
      categoryId: Value(categoryId),
      title: Value(_str(s['name']) ?? 'Movie $providerId'),
      type: const Value('movie'),
      providerId: Value(providerId),
      streamUrl: Value(streamUrl),
      containerExtension: Value(containerExt),
      posterUrl: Value(_str(s['stream_icon'])),
      rating: Value(_toDouble(s['rating'])),
      addedAt: Value(_unixToDateTime(s['added'])),
    );
  }

  ContentItemsTableCompanion _mapSingleSeriesStream(
    String playlistId,
    Map<String, dynamic> s,
    int idx,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    final providerId =
        _str(s['series_id']) ?? _str(s['stream_id']) ?? 'series_$idx';
    final catProviderId = _str(s['category_id']);
    final categoryId =
        catProviderId != null ? catByProviderId[catProviderId] : null;
    final containerExt = _str(s['container_extension']);
    final streamUrl = containerExt != null
        ? _client.buildSeriesStreamUrl(creds, providerId, containerExt)
        : null;

    return ContentItemsTableCompanion(
      playlistId: Value(playlistId),
      categoryId: Value(categoryId),
      title: Value(_str(s['name']) ?? 'Series $providerId'),
      type: const Value('series'),
      providerId: Value(providerId),
      streamUrl: Value(streamUrl),
      containerExtension: Value(containerExt),
      posterUrl: Value(_str(s['cover']) ?? _str(s['stream_icon'])),
      rating: Value(_toDouble(s['rating'])),
      addedAt: Value(_unixToDateTime(s['added'])),
    );
  }

  // ── Type-coercion utilities ───────────────────────────────────────────────

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  DateTime? _unixToDateTime(dynamic v) {
    final secs = _toInt(v);
    if (secs == null || secs == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }
}
