import 'package:drift/drift.dart';
import '../../../core/persistence/app_database.dart';
import 'stalker_client.dart';

class StalkerRepositoryImpl {
  final AppDatabase _db;
  final StalkerClient _client;

  StalkerRepositoryImpl({required AppDatabase db, required StalkerClient client})
      : _db = db,
        _client = client;

  Future<void> importStalkerPlaylist(String playlistId, StalkerCredentials creds) async {
    // 1. Handshake to obtain active session Bearer token
    var activeCreds = creds;
    final token = await _client.handshake(creds);
    if (token != null) {
      activeCreds = creds.copyWith(token: token);
    }

    // 2. Fetch categories for Live, VOD, and Series
    final liveCats = await _client.getLiveCategories(activeCreds);
    final vodCats = await _client.getVodCategories(activeCreds);
    final seriesCats = await _client.getSeriesCategories(activeCreds);

    final categoryCompanions = <CategoriesTableCompanion>[
      ...liveCats.map((c) => CategoriesTableCompanion(
            playlistId: Value(playlistId),
            name: Value(c['title']?.toString() ?? c['category_name']?.toString() ?? 'General'),
            type: const Value('live'),
            providerId: Value(c['id']?.toString() ?? ''),
          )),
      ...vodCats.map((c) => CategoriesTableCompanion(
            playlistId: Value(playlistId),
            name: Value(c['title']?.toString() ?? c['category_name']?.toString() ?? 'Movies'),
            type: const Value('movies'),
            providerId: Value(c['id']?.toString() ?? ''),
          )),
      ...seriesCats.map((c) => CategoriesTableCompanion(
            playlistId: Value(playlistId),
            name: Value(c['title']?.toString() ?? c['category_name']?.toString() ?? 'Series'),
            type: const Value('series'),
            providerId: Value(c['id']?.toString() ?? ''),
          )),
    ];

    if (categoryCompanions.isNotEmpty) {
      await _db.batchInsertCategories(categoryCompanions);
    }

    // Load persisted categories for foreign key resolution
    final savedLiveCats = await _db.getCategories(playlistId, 'live');
    final savedVodCats = await _db.getCategories(playlistId, 'movies');
    final savedSeriesCats = await _db.getCategories(playlistId, 'series');

    final liveCatMap = {for (final c in savedLiveCats) c.providerId: c.id};
    final vodCatMap = {for (final c in savedVodCats) c.providerId: c.id};
    final seriesCatMap = {for (final c in savedSeriesCats) c.providerId: c.id};

    // 3. Fetch Content Streams (Live channels, VOD streams, Series)
    final channels = await _client.getLiveChannels(activeCreds);
    final vodStreams = await _client.getVodStreams(activeCreds);
    final seriesStreams = await _client.getSeriesStreams(activeCreds);

    final contentCompanions = <ContentItemsTableCompanion>[];

    // Map Live TV
    for (final ch in channels) {
      final chId = ch['id']?.toString() ?? '';
      final name = ch['name']?.toString() ?? 'Unnamed Channel';
      final tvGenreId = ch['tv_genre_id']?.toString();
      final cmd = ch['cmd']?.toString() ?? '';
      final logo = ch['logo']?.toString();
      final categoryId = tvGenreId != null ? liveCatMap[tvGenreId] : null;

      contentCompanions.add(ContentItemsTableCompanion(
        playlistId: Value(playlistId),
        categoryId: Value(categoryId),
        title: Value(name),
        type: const Value('live'),
        providerId: Value(chId),
        streamUrl: Value(cmd),
        posterUrl: Value(logo),
      ));
    }

    // Map VOD Movies
    for (final vod in vodStreams) {
      final vodId = vod['id']?.toString() ?? '';
      final name = vod['name']?.toString() ?? vod['title']?.toString() ?? 'Unnamed Movie';
      final catId = vod['category_id']?.toString();
      final cmd = vod['cmd']?.toString() ?? '';
      final poster = vod['screenshot_uri']?.toString() ?? vod['poster']?.toString();
      final rating = double.tryParse(vod['rating']?.toString() ?? '');
      final categoryId = catId != null ? vodCatMap[catId] : null;

      contentCompanions.add(ContentItemsTableCompanion(
        playlistId: Value(playlistId),
        categoryId: Value(categoryId),
        title: Value(name),
        type: const Value('movie'),
        providerId: Value(vodId),
        streamUrl: Value(cmd),
        posterUrl: Value(poster),
        rating: Value(rating),
      ));
    }

    // Map Series
    for (final ser in seriesStreams) {
      final serId = ser['id']?.toString() ?? '';
      final name = ser['name']?.toString() ?? ser['title']?.toString() ?? 'Unnamed Series';
      final catId = ser['category_id']?.toString();
      final cmd = ser['cmd']?.toString() ?? '';
      final poster = ser['screenshot_uri']?.toString() ?? ser['poster']?.toString();
      final rating = double.tryParse(ser['rating']?.toString() ?? '');
      final categoryId = catId != null ? seriesCatMap[catId] : null;

      contentCompanions.add(ContentItemsTableCompanion(
        playlistId: Value(playlistId),
        categoryId: Value(categoryId),
        title: Value(name),
        type: const Value('series'),
        providerId: Value(serId),
        streamUrl: Value(cmd),
        posterUrl: Value(poster),
        rating: Value(rating),
      ));
    }

    // 4. Batch insert content items in chunks
    if (contentCompanions.isNotEmpty) {
      const chunkSize = 250;
      for (var i = 0; i < contentCompanions.length; i += chunkSize) {
        final chunk = contentCompanions.skip(i).take(chunkSize).toList();
        await _db.batchInsertContentItems(chunk);
      }
    }

    // 5. Update Playlist metadata
    await (_db.update(_db.playlistsTable)..where((t) => t.id.equals(playlistId)))
        .write(PlaylistsTableCompanion(
      channelCount: Value(contentCompanions.length),
      lastUpdated: Value(DateTime.now()),
    ));
  }
}
