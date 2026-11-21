import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../data/playlist_repository_impl.dart';
import '../domain/playlist_repository.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides a [PlaylistNotifier] backed by the live [AppDatabase] and
/// [ApiClient] from the Riverpod dependency graph.
final playlistNotifierProvider =
    AsyncNotifierProvider<PlaylistNotifier, List<PlaylistsTableData>>(
  PlaylistNotifier.new,
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Watches all playlists in the database and exposes import / refresh actions.
class PlaylistNotifier extends AsyncNotifier<List<PlaylistsTableData>> {
  late final PlaylistRepository _repository;

  @override
  Future<List<PlaylistsTableData>> build() async {
    final db = ref.watch(databaseProvider);
    final apiClient = ref.watch(apiClientProvider);

    _repository = PlaylistRepositoryImpl(db, apiClient);

    // Return the playlists from the database
    return db.getAllPlaylists();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Downloads the M3U at [url] and imports it under [playlistId].
  Future<void> importFromUrl(String playlistId, String url) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state =
        'Downloading M3U playlist...';
    state = const AsyncValue.loading();
    try {
      await _repository.importFromUrl(
        playlistId,
        url,
        onProgress: (status) {
          ref.read(playlistSyncStatusProvider.notifier).state = status;
        },
      );
      state = AsyncValue.data(await _currentPlaylists());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      ref.read(isSyncingPlaylistProvider.notifier).state = false;
      ref.read(playlistSyncStatusProvider.notifier).state = null;
    }
  }

  /// Reads the local M3U file at [filePath] and imports it under [playlistId].
  Future<void> importFromFile(String playlistId, String filePath) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state =
        'Reading M3U file...';
    state = const AsyncValue.loading();
    try {
      await _repository.importFromFile(
        playlistId,
        filePath,
        onProgress: (status) {
          ref.read(playlistSyncStatusProvider.notifier).state = status;
        },
      );
      state = AsyncValue.data(await _currentPlaylists());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      ref.read(isSyncingPlaylistProvider.notifier).state = false;
      ref.read(playlistSyncStatusProvider.notifier).state = null;
    }
  }

  /// Re-fetches the playlist identified by [playlistId] from its stored source.
  Future<void> refreshPlaylist(String playlistId) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state =
        'Syncing M3U playlist...';
    state = const AsyncValue.loading();
    try {
      await _repository.refreshPlaylist(
        playlistId,
        onProgress: (status) {
          ref.read(playlistSyncStatusProvider.notifier).state = status;
        },
      );
      state = AsyncValue.data(await _currentPlaylists());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    } finally {
      ref.read(isSyncingPlaylistProvider.notifier).state = false;
      ref.read(playlistSyncStatusProvider.notifier).state = null;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Returns the current list of playlists from the database (one-shot read).
  Future<List<PlaylistsTableData>> _currentPlaylists() {
    final db = ref.read(databaseProvider);
    return db.getAllPlaylists();
  }
}
