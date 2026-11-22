import 'package:flutter_test/flutter_test.dart';

import 'package:filimu_plus/core/persistence/app_database.dart';
import 'package:filimu_plus/features/player/tiss/channel_grouping_engine.dart';
import 'package:filimu_plus/features/player/tiss/tiss_controller.dart';

ContentItemsTableData _live(int id, String title) => ContentItemsTableData(
      id: id,
      playlistId: 'stress_pl',
      categoryId: (id % 5) + 1,
      title: title,
      type: 'live',
      providerId: 'ch_$id',
      streamUrl: 'http://provider.test/live/$id.ts',
      posterUrl: null,
      epgChannelId: null,
      tvArchive: 0,
      tvArchiveDuration: 0,
    );

void main() {
  group('Production Stability Stress Tests', () {
    test('100 rapid channel switches keep TISS state clean without leaks', () {
      final ctrl = TissController();
      final sw = Stopwatch()..start();

      for (var i = 0; i < 100; i++) {
        final candidates = [
          _live(i * 3 + 1, 'Channel $i 4K'),
          _live(i * 3 + 2, 'Channel $i 1080p'),
          _live(i * 3 + 3, 'Channel $i 720p'),
        ];
        final logical = ChannelGroupingEngine.groupChannels(candidates).first;
        ctrl.attachLogicalChannel(logical);
        ctrl.confirmPlayback(width: 1920, height: 1080);

        // Simulate occasional failover during switching
        if (i % 10 == 0) {
          final ranked = ctrl.rankedFailoverCandidates();
          expect(ranked, isNotEmpty);
          ctrl.commitVerifiedFailover(ranked.first, reason: 'stress_failover');
        }
        ctrl.detach();
      }

      sw.stop();
      expect(ctrl.activeChannel, isNull);
      expect(ctrl.activeStream, isNull);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
