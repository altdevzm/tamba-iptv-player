import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import '../security/secure_storage_service.dart';
import '../network/api_client.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

final activePlaylistIdProvider = StateProvider<String?>((ref) => null);

/// Auto-resolves the active playlist ID if none has been explicitly selected yet
final effectivePlaylistIdProvider = StreamProvider<String?>((ref) {
  final explicitId = ref.watch(activePlaylistIdProvider);
  if (explicitId != null) return Stream.value(explicitId);

  final db = ref.watch(databaseProvider);
  return db.watchAllPlaylists().map((playlists) {
    if (playlists.isNotEmpty) {
      final firstId = playlists.first.id;
      // Auto-populate activePlaylistIdProvider
      Future.microtask(() {
        if (ref.read(activePlaylistIdProvider) == null) {
          ref.read(activePlaylistIdProvider.notifier).state = firstId;
        }
      });
      return firstId;
    }
    return null;
  });
});
final isSyncingPlaylistProvider = StateProvider<bool>((ref) => false);
final playlistSyncStatusProvider = StateProvider<String?>((ref) => null);

