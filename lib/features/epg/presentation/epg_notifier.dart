import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../data/epg_repository_impl.dart';
import '../data/channel_matcher.dart';

final epgRepositoryProvider = Provider<EpgRepositoryImpl>((ref) {
  final db = ref.watch(databaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  return EpgRepositoryImpl(db: db, dio: apiClient.dio);
});

class EpgNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> importEpg(String url) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(epgRepositoryProvider);
      await repo.importEpgFromUrl(url);

      // Match EPG to content items after import
      final db = ref.read(databaseProvider);
      final matcher = ChannelMatcher();
      await matcher.matchAllChannels(db);
    });
  }
}

final epgNotifierProvider = AsyncNotifierProvider<EpgNotifier, void>(() {
  return EpgNotifier();
});

final currentProgramProvider = StreamProvider.family<List<EpgProgramsTableData>, String>((ref, channelId) {
  final repo = ref.watch(epgRepositoryProvider);
  return repo.watchCurrentPrograms(channelId);
});

final channelScheduleProvider = StreamProvider.family<List<EpgProgramsTableData>, String>((ref, channelId) {
  final repo = ref.watch(epgRepositoryProvider);
  return repo.watchChannelSchedule(channelId);
});
