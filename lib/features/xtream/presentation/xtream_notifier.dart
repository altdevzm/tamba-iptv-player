import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/database_provider.dart';
import '../data/xtream_client.dart';
import '../data/xtream_repository_impl.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final xtreamNotifierProvider =
    AsyncNotifierProvider<XtreamNotifier, void>(XtreamNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class XtreamNotifier extends AsyncNotifier<void> {
  late XtreamRepositoryImpl _repository;

  @override
  Future<void> build() async {
    final db = ref.watch(databaseProvider);
    final apiClient = ref.watch(apiClientProvider);
    _repository = XtreamRepositoryImpl(
      db: db,
      client: XtreamClient(apiClient.dio),
    );
  }

  /// Imports a new Xtream Codes playlist by verifying credentials, fetching
  /// all categories and streams, and persisting them to the local database.
  Future<void> importPlaylist(
    String playlistId,
    XtreamCredentials creds,
  ) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state = 'Connecting to Xtream server...';
    state = const AsyncLoading();
    try {
      await _repository.importXtreamPlaylist(
        playlistId,
        creds,
        onProgress: (status) {
          ref.read(playlistSyncStatusProvider.notifier).state = status;
        },
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } finally {
      ref.read(isSyncingPlaylistProvider.notifier).state = false;
      ref.read(playlistSyncStatusProvider.notifier).state = null;
    }
  }

  /// Re-syncs (refreshes) an existing Xtream Codes playlist.
  Future<void> refreshPlaylist(
    String playlistId,
    XtreamCredentials creds,
  ) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state = 'Syncing playlist with Xtream server...';
    state = const AsyncLoading();
    try {
      await _repository.refreshXtreamPlaylist(
        playlistId,
        creds,
        onProgress: (status) {
          ref.read(playlistSyncStatusProvider.notifier).state = status;
        },
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } finally {
      ref.read(isSyncingPlaylistProvider.notifier).state = false;
      ref.read(playlistSyncStatusProvider.notifier).state = null;
    }
  }
}
