import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/database_provider.dart';
import '../data/stalker_client.dart';
import '../data/stalker_repository_impl.dart';

class StalkerNotifier extends AsyncNotifier<void> {
  late StalkerRepositoryImpl _repository;

  @override
  Future<void> build() async {
    final db = ref.watch(databaseProvider);
    final apiClient = ref.watch(apiClientProvider);
    _repository = StalkerRepositoryImpl(
      db: db,
      client: StalkerClient(apiClient.dio),
    );
  }

  Future<void> importPlaylist(String playlistId, StalkerCredentials creds) async {
    ref.read(isSyncingPlaylistProvider.notifier).state = true;
    ref.read(playlistSyncStatusProvider.notifier).state =
        'Connecting to Stalker portal...';
    state = const AsyncLoading();
    try {
      await _repository.importStalkerPlaylist(
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

final stalkerNotifierProvider =
    AsyncNotifierProvider<StalkerNotifier, void>(StalkerNotifier.new);

