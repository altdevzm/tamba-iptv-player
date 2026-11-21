import 'package:drift/drift.dart';
import '../../../core/persistence/app_database.dart';
import 'stalker_client.dart';

class StalkerRepositoryImpl {
  final AppDatabase _db;
  final StalkerClient _client;

  StalkerRepositoryImpl({required AppDatabase db, required StalkerClient client})
      : _db = db,
        _client = client;

  Future<void> importStalkerPlaylist(
    String playlistId,
    StalkerCredentials creds, {
    void Function(String status)? onProgress,
  }) async {
    final normalizedCreds = StalkerCredentials(
      serverUrl: creds.serverUrl.trim(),
      macAddress: StalkerClient.normalizeMac(creds.macAddress),
      token: creds.token,
    );

    // 1. Handshake to obtain active session Bearer token & activate profile
    onProgress?.call('Connecting to Stalker portal...');
    var activeCreds = normalizedCreds;
    final token = await _client.handshake(normalizedCreds);
    if (token != null && token.isNotEmpty) {
      activeCreds = normalizedCreds.copyWith(token: token);
      await _client.getProfile(activeCreds);
    }

    // 2. Fetch categories for Live, VOD, and Series (tolerate portals that only
    //    support a subset of these sections)
    onProgress?.call('Fetching Stalker categories...');
    List<Map<String, dynamic>> liveCats = [];
    List<Map<String, dynamic>> vodCats = [];
    List<Map<String, dynamic>> seriesCats = [];

    try {
      liveCats = await _client.getLiveCategories(activeCreds);
    } catch (_) {}
    try {
      vodCats = await _client.getVodCategories(activeCreds);
    } catch (_) {}
    try {
      seriesCats = await _client.getSeriesCategories(activeCreds);
    } catch (_) {}

    // 3. Fetch Content Streams (Live channels, VOD streams, Series)
    onProgress?.call('Downloading channels & VOD catalog...');
    List<Map<String, dynamic>> channels = [];
    List<Map<String, dynamic>> vodStreams = [];
    List<Map<String, dynamic>> seriesStreams = [];

    try {
      channels = await _client.getLiveChannels(activeCreds);
    } catch (_) {}
    try {
      vodStreams = await _client.getVodStreams(activeCreds);
    } catch (_) {}
    try {
      seriesStreams = await _client.getSeriesStreams(activeCreds);
    } catch (_) {}

    if (channels.isEmpty && vodStreams.isEmpty && seriesStreams.isEmpty) {
      throw Exception(
        'Could not load channels from Stalker portal. Please check the Portal URL and MAC address (and ensure the MAC is active on the server).',
      );
    }

    onProgress?.call(
      'Saving ${channels.length + vodStreams.length + seriesStreams.length} items...',
    );

    // Clear previous categories & items so refresh never hits UNIQUE constraints
    await (_db.delete(_db.contentItemsTable)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
    await (_db.delete(_db.categoriesTable)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();

    // Deduplicate categories by (type, providerId)
    final seenCatKeys = <String>{};
    final categoryCompanions = <CategoriesTableCompanion>[];

    void addCategories(
      List<Map<String, dynamic>> cats,
      String type,
      String fallbackName,
    ) {
      for (var i = 0; i < cats.length; i++) {
        final c = cats[i];
        final rawId = c['id']?.toString().trim() ?? '';
        final providerId = rawId.isNotEmpty ? rawId : '${type}_cat_$i';
        if (!seenCatKeys.add('$type::$providerId')) continue;
        final name = c['title']?.toString().trim() ??
            c['category_name']?.toString().trim() ??
            fallbackName;
        categoryCompanions.add(
          CategoriesTableCompanion.insert(
            playlistId: playlistId,
            name: name.isNotEmpty ? name : fallbackName,
            type: type,
            providerId: providerId,
          ),
        );
      }
    }

    addCategories(liveCats, 'live', 'General');
    addCategories(vodCats, 'movies', 'Movies');
    addCategories(seriesCats, 'series', 'Series');

    if (categoryCompanions.isNotEmpty) {
      for (var i = 0; i < categoryCompanions.length; i += 500) {
        final end = (i + 500 < categoryCompanions.length)
            ? i + 500
            : categoryCompanions.length;
        await _db.batchInsertCategories(categoryCompanions.sublist(i, end));
      }
    }

    // Load persisted categories for foreign key resolution
    final savedLiveCats = await _db.getCategories(playlistId, 'live');
    final savedVodCats = await _db.getCategories(playlistId, 'movies');
    final savedSeriesCats = await _db.getCategories(playlistId, 'series');

    final liveCatMap = {for (final c in savedLiveCats) c.providerId: c.id};
    final vodCatMap = {for (final c in savedVodCats) c.providerId: c.id};
    final seriesCatMap = {for (final c in savedSeriesCats) c.providerId: c.id};

    final seenItemKeys = <String>{};
    final contentCompanions = <ContentItemsTableCompanion>[];

    String uniqueProviderId(String type, String rawId, int idx) {
      final base = rawId.trim().isNotEmpty ? rawId.trim() : '${type}_$idx';
      var candidate = base;
      if (!seenItemKeys.add('$type::$candidate')) {
        candidate = '${base}_$idx';
        seenItemKeys.add('$type::$candidate');
      }
      return candidate;
    }

    // Map Live TV
    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final chId = uniqueProviderId('live', ch['id']?.toString() ?? '', i);
      final name = ch['name']?.toString() ?? 'Unnamed Channel';
      final tvGenreId = ch['tv_genre_id']?.toString();
      final cmd = ch['cmd']?.toString() ?? '';
      final logo = ch['logo']?.toString();
      final categoryId = tvGenreId != null ? liveCatMap[tvGenreId] : null;

      contentCompanions.add(ContentItemsTableCompanion.insert(
        playlistId: playlistId,
        categoryId: Value(categoryId),
        title: name,
        type: 'live',
        providerId: chId,
        streamUrl: Value(cmd),
        posterUrl: Value(logo),
      ));
    }

    // Map VOD Movies
    for (var i = 0; i < vodStreams.length; i++) {
      final vod = vodStreams[i];
      final vodId = uniqueProviderId('movie', vod['id']?.toString() ?? '', i);
      final name =
          vod['name']?.toString() ?? vod['title']?.toString() ?? 'Unnamed Movie';
      final catId = vod['category_id']?.toString();
      final cmd = vod['cmd']?.toString() ?? '';
      final poster =
          vod['screenshot_uri']?.toString() ?? vod['poster']?.toString();
      final rating = double.tryParse(vod['rating']?.toString() ?? '');
      final categoryId = catId != null ? vodCatMap[catId] : null;

      contentCompanions.add(ContentItemsTableCompanion.insert(
        playlistId: playlistId,
        categoryId: Value(categoryId),
        title: name,
        type: 'movie',
        providerId: vodId,
        streamUrl: Value(cmd),
        posterUrl: Value(poster),
        rating: Value(rating),
      ));
    }

    // Map Series
    for (var i = 0; i < seriesStreams.length; i++) {
      final ser = seriesStreams[i];
      final serId = uniqueProviderId('series', ser['id']?.toString() ?? '', i);
      final name =
          ser['name']?.toString() ?? ser['title']?.toString() ?? 'Unnamed Series';
      final catId = ser['category_id']?.toString();
      final cmd = ser['cmd']?.toString() ?? '';
      final poster =
          ser['screenshot_uri']?.toString() ?? ser['poster']?.toString();
      final rating = double.tryParse(ser['rating']?.toString() ?? '');
      final categoryId = catId != null ? seriesCatMap[catId] : null;

      contentCompanions.add(ContentItemsTableCompanion.insert(
        playlistId: playlistId,
        categoryId: Value(categoryId),
        title: name,
        type: 'series',
        providerId: serId,
        streamUrl: Value(cmd),
        posterUrl: Value(poster),
        rating: Value(rating),
      ));
    }

    // 4. Batch insert content items in chunks
    const chunkSize = 2000;
    for (var i = 0; i < contentCompanions.length; i += chunkSize) {
      final end = (i + chunkSize < contentCompanions.length)
          ? i + chunkSize
          : contentCompanions.length;
      await _db.batchInsertContentItemsFast(contentCompanions.sublist(i, end));
    }

    // 5. Update Playlist metadata
    await (_db.update(_db.playlistsTable)..where((t) => t.id.equals(playlistId)))
        .write(PlaylistsTableCompanion(
      channelCount: Value(contentCompanions.length),
      lastUpdated: Value(DateTime.now()),
    ));
  }
}
