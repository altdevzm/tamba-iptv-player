import 'dart:io';

import 'package:drift/drift.dart' as drift;

import '../../../core/persistence/app_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/playlist_repository.dart';
import 'm3u_parser.dart';

/// Concrete [PlaylistRepository] backed by Drift (SQLite) and Dio.
class PlaylistRepositoryImpl implements PlaylistRepository {
  final AppDatabase _db;
  final ApiClient _apiClient;

  const PlaylistRepositoryImpl(AppDatabase db, ApiClient apiClient)
      : _db = db,
        _apiClient = apiClient;

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<void> importFromUrl(String playlistId, String url) async {
    final content = await _downloadM3u(url);
    await _parseAndStore(playlistId, content);
  }

  @override
  Future<void> importFromFile(String playlistId, String filePath) async {
    final content = await File(filePath).readAsString();
    await _parseAndStore(playlistId, content);
  }

  @override
  Future<void> refreshPlaylist(String playlistId) async {
    final playlist = await _db.getPlaylist(playlistId);
    if (playlist == null) return;

    if (playlist.url != null && playlist.url!.isNotEmpty) {
      await importFromUrl(playlistId, playlist.url!);
    } else if (playlist.filePath != null && playlist.filePath!.isNotEmpty) {
      await importFromFile(playlistId, playlist.filePath!);
    }
    // If neither url nor filePath is set there is nothing to refresh.
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Downloads the raw M3U text from [url] via Dio.
  Future<String> _downloadM3u(String url) async {
    final response = await _apiClient.dio.get<String>(url);
    return response.data ?? '';
  }

  /// Runs the M3U parser in a background isolate, then batch-inserts the
  /// results into the database and updates the playlist metadata.
  Future<void> _parseAndStore(String playlistId, String content) async {
    // Parse on a background isolate (Isolate.run is called inside parseM3u).
    final channels = await parseM3u(content);

    if (channels.isEmpty) {
      await _updatePlaylistMeta(playlistId, 0);
      return;
    }

    // ── 1. Extract unique group-titles → CategoriesTable ───────────────────
    // Build a deduplicated ordered list of group names.
    final seenGroups = <String>{};
    final orderedGroups = <String>[];
    for (final ch in channels) {
      final group = ch.groupTitle ?? 'Uncategorised';
      if (seenGroups.add(group)) orderedGroups.add(group);
    }

    final categoryCompanions = orderedGroups
        .map(
          (g) => CategoriesTableCompanion.insert(
            playlistId: playlistId,
            name: g,
            type: 'live',
            // Use the group name as the provider ID — it's the natural key for
            // M3U groups (no server-assigned numeric ID exists).
            providerId: g,
          ),
        )
        .toList();

    await _db.batchInsertCategories(categoryCompanions);

    // Reload categories so we can resolve group-name → DB row ID.
    final savedCategories = await _db.getCategories(playlistId, 'live');
    final categoryIdByName = <String, int>{
      for (final cat in savedCategories) cat.name: cat.id,
    };

    // ── 2. Insert channels → ContentItemsTable ─────────────────────────────
    final contentCompanions = <ContentItemsTableCompanion>[];

    for (var idx = 0; idx < channels.length; idx++) {
      final ch = channels[idx];
      final group = ch.groupTitle ?? 'Uncategorised';
      final categoryId = categoryIdByName[group];

      contentCompanions.add(
        ContentItemsTableCompanion.insert(
          playlistId: playlistId,
          categoryId: drift.Value(categoryId),
          title: ch.title,
          type: 'live',
          // Use a stable provider ID: prefer tvgId, fall back to title+index
          // to ensure uniqueness within the playlist.
          providerId: ch.tvgId?.isNotEmpty == true
              ? ch.tvgId!
              : '${ch.title}_$idx',
          streamUrl: drift.Value(ch.streamUrl),
          posterUrl: drift.Value(ch.logoUrl),
          epgChannelId: drift.Value(ch.tvgId),
          // Map catchup-days to tvArchiveDuration (seconds would be more
          // precise, but days is what the M3U spec provides).
          tvArchiveDuration: drift.Value(ch.catchupDays),
          tvArchive: drift.Value(ch.catchupDays > 0 ? 1 : 0),
        ),
      );
    }

    await _db.batchInsertContentItems(contentCompanions);

    // ── 3. Update playlist metadata ────────────────────────────────────────
    await _updatePlaylistMeta(playlistId, channels.length);
  }

  /// Stamps [channelCount] and `lastUpdated = now` on the playlist row.
  Future<void> _updatePlaylistMeta(String playlistId, int channelCount) async {
    await (_db.update(_db.playlistsTable)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsTableCompanion(
        channelCount: drift.Value(channelCount),
        lastUpdated: drift.Value(DateTime.now()),
      ),
    );
  }
}
