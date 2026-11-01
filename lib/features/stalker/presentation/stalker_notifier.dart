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
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.importStalkerPlaylist(playlistId, creds),
    );
  }
}

final stalkerNotifierProvider =
    AsyncNotifierProvider<StalkerNotifier, void>(StalkerNotifier.new);

