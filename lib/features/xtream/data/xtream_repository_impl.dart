import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'xtream_client.dart';

/// Repository that imports or refreshes an Xtream Codes playlist into the
/// local Drift database.
class XtreamRepositoryImpl {
  final AppDatabase _db;
  final XtreamClient _client;

  XtreamRepositoryImpl({
    required AppDatabase db,
    required XtreamClient client,
  })  : _db = db,
        _client = client;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Imports a brand-new Xtream playlist.  Inserts rows and updates the
  /// playlist metadata on success.
  Future<void> importXtreamPlaylist(
    String playlistId,
    XtreamCredentials creds, {
    void Function(String status)? onProgress,
  }) =>
      _syncPlaylist(playlistId, creds, onProgress: onProgress);

  /// Re-syncs an existing playlist, upserting all rows.
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
    // 1. Verify credentials (proceed even if get_account_info is restricted).
    onProgress?.call('Authenticating with Xtream server...');
    try {
      await _client.getAccountInfo(creds);
    } catch (_) {}

    // 2. Fetch categories resiliently.
    onProgress?.call('Downloading categories (Live, Movies, Series)...');
    final liveCategories = await _client.getLiveCategories(creds);
    final vodCategories = await _client.getVodCategories(creds);
    final seriesCategories = await _client.getSeriesCategories(creds);

    // 3. Batch-insert categories.
    final categoryCompanions = [
      ..._mapCategories(playlistId, liveCategories, 'live'),
      ..._mapCategories(playlistId, vodCategories, 'movies'),
      ..._mapCategories(playlistId, seriesCategories, 'series'),
    ];
    if (categoryCompanions.isNotEmpty) {
      await _db.batchInsertCategories(categoryCompanions);
    }

    // Reload the persisted categories so we have their auto-incremented ids.
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

    // 4-6. Fetch streams resiliently.
    onProgress?.call('Downloading Live TV channels...');
    final liveStreams = await _client.getLiveStreams(creds);

    onProgress?.call('Downloading Movies & Series catalog...');
    final vodStreams = await _client.getVodStreams(creds);
    final seriesStreams = await _client.getSeriesStreams(creds);

    // Map to companion objects.
    onProgress?.call('Saving channels to local library...');
    final contentCompanions = [
      ..._mapLiveStreams(playlistId, liveStreams, liveCatByProviderId, creds),
      ..._mapVodStreams(playlistId, vodStreams, vodCatByProviderId, creds),
      ..._mapSeriesStreams(
          playlistId, seriesStreams, seriesCatByProviderId, creds),
    ];

    if (contentCompanions.isNotEmpty) {
      await _db.batchInsertContentItems(contentCompanions);
    }

    // 7. Update playlist metadata safely without violating NOT NULL constraints.
    final totalCount = contentCompanions.length;
    await (_db.update(_db.playlistsTable)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsTableCompanion(
        channelCount: Value(totalCount),
        lastUpdated: Value(DateTime.now()),
      ),
    );
    onProgress?.call('Complete! Imported $totalCount items.');
  }

  // ── Mapping helpers ───────────────────────────────────────────────────────

  List<CategoriesTableCompanion> _mapCategories(
    String playlistId,
    List<Map<String, dynamic>> raw,
    String type,
  ) {
    return raw.map((c) {
      return CategoriesTableCompanion(
        playlistId: Value(playlistId),
        name: Value(_str(c['category_name']) ?? _str(c['name']) ?? 'Unknown'),
        type: Value(type),
        providerId: Value(_str(c['category_id']) ?? ''),
      );
    }).toList();
  }

  List<ContentItemsTableCompanion> _mapLiveStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    return raw.map((s) {
      final providerId = _str(s['stream_id']) ?? '';
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
        title: Value(_str(s['name']) ?? ''),
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
    }).toList();
  }

  List<ContentItemsTableCompanion> _mapVodStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    return raw.map((s) {
      final providerId = _str(s['stream_id']) ?? '';
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
        title: Value(_str(s['name']) ?? ''),
        type: const Value('movie'),
        providerId: Value(providerId),
        streamUrl: Value(streamUrl),
        containerExtension: Value(containerExt),
        posterUrl: Value(_str(s['stream_icon'])),
        rating: Value(_toDouble(s['rating'])),
        addedAt: Value(_unixToDateTime(s['added'])),
      );
    }).toList();
  }

  List<ContentItemsTableCompanion> _mapSeriesStreams(
    String playlistId,
    List<Map<String, dynamic>> raw,
    Map<String, int> catByProviderId,
    XtreamCredentials creds,
  ) {
    return raw.map((s) {
      final providerId = _str(s['series_id']) ?? _str(s['stream_id']) ?? '';
      final catProviderId = _str(s['category_id']);
      final categoryId =
          catProviderId != null ? catByProviderId[catProviderId] : null;
      // Series don't have a direct stream URL at the series level; use the
      // series detail page URL pattern (no extension needed at this level).
      final containerExt = _str(s['container_extension']);
      final streamUrl = containerExt != null
          ? _client.buildSeriesStreamUrl(creds, providerId, containerExt)
          : null;

      return ContentItemsTableCompanion(
        playlistId: Value(playlistId),
        categoryId: Value(categoryId),
        title: Value(_str(s['name']) ?? ''),
        type: const Value('series'),
        providerId: Value(providerId),
        streamUrl: Value(streamUrl),
        containerExtension: Value(containerExt),
        posterUrl: Value(_str(s['cover']) ?? _str(s['stream_icon'])),
        rating: Value(_toDouble(s['rating'])),
        addedAt: Value(_unixToDateTime(s['added'])),
      );
    }).toList();
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
