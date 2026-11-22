import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/persistence/app_database.dart';
import 'xtream_client.dart';

/// Repository that imports or refreshes an Xtream Codes playlist into the
/// local Drift database safely without deleting existing data on failure.
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

  // ── Core sync logic ───────────────────────────────────────────────────────

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
        await _client.getAccountInfo(creds);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          throw Exception(
            'Authentication failed (HTTP $code). Check your username, password, or subscription.',
          );
        }
        // Some panels restrict get_account_info; proceed to fetch categories.
      } catch (_) {}

      // 2. Download all categories & streams BEFORE modifying local SQLite so
      //    any network/auth failure leaves the existing playlist 100% intact.
      onProgress?.call('Downloading categories (Live, Movies, Series)...');
      final liveCategories = await _client.getLiveCategories(creds);
      final vodCategories = await _client.getVodCategories(creds);
      final seriesCategories = await _client.getSeriesCategories(creds);

      onProgress?.call('Downloading Live TV channels...');
      final liveStreams = await _client.getLiveStreams(creds);

      onProgress?.call('Downloading Movies & Series catalog...');
      final vodStreams = await _client.getVodStreams(creds);
      final seriesStreams = await _client.getSeriesStreams(creds);

      final rawTotal =
          liveStreams.length + vodStreams.length + seriesStreams.length;
      if (rawTotal == 0) {
        throw Exception(
          'Xtream server returned 0 channels. Your existing playlist was preserved.',
        );
      }

      // 3. Deduplicate categories & upsert in safe 500-row chunks inside a
      //    transaction (composite-key ON CONFLICT preserves IDs & hidden flags).
      onProgress?.call('Saving categories...');
      final categoryCompanions = <CategoriesTableCompanion>[
        ..._mapCategories(playlistId, liveCategories, 'live'),
        ..._mapCategories(playlistId, vodCategories, 'movies'),
        ..._mapCategories(playlistId, seriesCategories, 'series'),
      ];

      int totalSaved = 0;

      await _db.transaction(() async {
        const catChunk = 500;
        for (var i = 0; i < categoryCompanions.length; i += catChunk) {
          final end = (i + catChunk < categoryCompanions.length)
              ? i + catChunk
              : categoryCompanions.length;
          await _db.batchInsertCategories(categoryCompanions.sublist(i, end));
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

        // 4. Upsert streams in 1,500-item chunks so RAM stays low on 1–2GB Smart TVs.
        const itemChunk = 1500;
        final seenKeys = <String>{};

        Future<void> upsertStreamBatch(
          List<ContentItemsTableCompanion> items,
          String label,
        ) async {
          for (var i = 0; i < items.length; i += itemChunk) {
            final end = (i + itemChunk < items.length) ? i + itemChunk : items.length;
            await _db.batchInsertContentItems(items.sublist(i, end));
            totalSaved += (end - i);
            onProgress?.call('Saving $label ($totalSaved / $rawTotal)...');
          }
        }

        await upsertStreamBatch(
          _mapLiveStreams(
              playlistId, liveStreams, liveCatByProviderId, creds, seenKeys),
          'Live TV',
        );
        await upsertStreamBatch(
          _mapVodStreams(
              playlistId, vodStreams, vodCatByProviderId, creds, seenKeys),
          'Movies',
        );
        await upsertStreamBatch(
          _mapSeriesStreams(
              playlistId, seriesStreams, seriesCatByProviderId, creds, seenKeys),
          'Series',
        );

        // 5. Update playlist metadata atomically inside the same transaction.
        await (_db.update(_db.playlistsTable)
              ..where((t) => t.id.equals(playlistId)))
            .write(
          PlaylistsTableCompanion(
            channelCount: Value(totalSaved),
            lastUpdated: Value(DateTime.now()),
          ),
        );
      });

      AppLogger.info(
        'XtreamSync',
        'Synced $totalSaved items in ${sw.elapsedMilliseconds}ms',
      );
      onProgress?.call('Complete! Synced $totalSaved items.');
    } on DioException catch (e, st) {
      AppLogger.error('XtreamSync', 'Network error during Xtream sync', e, st);
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

  List<ContentItemsTableCompanion> _mapLiveStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
    Set<String> seenKeys,
  ) {
    final result = <ContentItemsTableCompanion>[];
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      final providerId = _str(s['stream_id']) ?? 'live_$i';
      if (!seenKeys.add('live::$providerId')) continue;
      final catProviderId = _str(s['category_id']);
      final categoryId =
          catProviderId != null ? catByProviderId[catProviderId] : null;
      final direct = _str(s['direct_source']);
      final streamUrl = (direct != null && direct.startsWith('http'))
          ? direct
          : _client.buildLiveStreamUrl(creds, providerId, ext: 'ts');

      result.add(
        ContentItemsTableCompanion(
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
        ),
      );
    }
    return result;
  }

  List<ContentItemsTableCompanion> _mapVodStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
    Set<String> seenKeys,
  ) {
    final result = <ContentItemsTableCompanion>[];
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      final providerId = _str(s['stream_id']) ?? 'movie_$i';
      if (!seenKeys.add('movie::$providerId')) continue;
      final containerExt = _str(s['container_extension']) ?? 'mp4';
      final catProviderId = _str(s['category_id']);
      final categoryId =
          catProviderId != null ? catByProviderId[catProviderId] : null;
      final direct = _str(s['direct_source']);
      final streamUrl = (direct != null && direct.startsWith('http'))
          ? direct
          : _client.buildVodStreamUrl(creds, providerId, containerExt);

      result.add(
        ContentItemsTableCompanion(
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
        ),
      );
    }
    return result;
  }

  List<ContentItemsTableCompanion> _mapSeriesStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
    Set<String> seenKeys,
  ) {
    final result = <ContentItemsTableCompanion>[];
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      final providerId =
          _str(s['series_id']) ?? _str(s['stream_id']) ?? 'series_$i';
      if (!seenKeys.add('series::$providerId')) continue;
      final catProviderId = _str(s['category_id']);
      final categoryId =
          catProviderId != null ? catByProviderId[catProviderId] : null;
      final containerExt = _str(s['container_extension']);
      final streamUrl = containerExt != null
          ? _client.buildSeriesStreamUrl(creds, providerId, containerExt)
          : null;

      result.add(
        ContentItemsTableCompanion(
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
        ),
      );
    }
    return result;
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
