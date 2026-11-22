import 'package:flutter_test/flutter_test.dart';

import 'package:filimu_plus/core/persistence/app_database.dart';
import 'package:filimu_plus/features/player/tiss/channel_grouping_engine.dart';
import 'package:filimu_plus/features/player/tiss/tiss_controller.dart';
import 'package:filimu_plus/features/player/tiss/tiss_models.dart';

ContentItemsTableData _liveRow({
  required int id,
  required String providerId,
  required String title,
  required String url,
  String? epgId,
  String? logo,
  int categoryId = 1,
}) {
  return ContentItemsTableData(
    id: id,
    playlistId: 'pl1',
    categoryId: categoryId,
    title: title,
    type: 'live',
    providerId: providerId,
    streamUrl: url,
    posterUrl: logo,
    epgChannelId: epgId,
    tvArchive: 0,
    tvArchiveDuration: 0,
  );
}

void main() {
  group('TISS Acceptance Tests (Tests 1–10)', () {
    List<LogicalChannel> buildTvOneChannels() {
      return ChannelGroupingEngine.groupChannels([
        _liveRow(
          id: 1,
          providerId: 'tv1_4k',
          title: 'TV ONE 4K',
          url: 'http://provider.test/live/tvone_4k.m3u8',
          epgId: 'tvone.uk',
          logo: 'http://provider.test/logos/tvone.png',
        ),
        _liveRow(
          id: 2,
          providerId: 'tv1_1080',
          title: 'TV ONE 1080P',
          url: 'http://provider.test/live/tvone_1080.m3u8',
          epgId: 'tvone.uk',
          logo: 'http://provider.test/logos/tvone.png',
        ),
        _liveRow(
          id: 3,
          providerId: 'tv1_720',
          title: 'TV ONE 720P',
          url: 'http://provider.test/live/tvone_720.m3u8',
          epgId: 'tvone.uk',
          logo: 'http://provider.test/logos/tvone.png',
        ),
        _liveRow(
          id: 4,
          providerId: 'tv1_480',
          title: 'TV ONE 480P',
          url: 'http://provider.test/live/tvone_480.m3u8',
          epgId: 'tvone.uk',
          logo: 'http://provider.test/logos/tvone.png',
        ),
      ]);
    }

    test('TEST 1: Healthy 1080p stream does not trigger automatic switching', () {
      final groups = buildTvOneChannels();
      expect(groups.length, 1);
      final tvOne = groups.first;
      expect(tvOne.alternatives.length, 4);

      final tiss = TissController();
      final alt1080 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.fhd1080);
      tiss.attachLogicalChannel(tvOne, initialStream: alt1080, autoMode: true);
      tiss.confirmPlayback(startupMs: 900, width: 1920, height: 1080);

      // Single temporary rebuffer below threshold (2) must NOT switch
      expect(tiss.recordRebufferAndShouldFailover(), isFalse);
      expect(tiss.activeStream?.tier, StreamQualityTier.fhd1080);
      expect(tiss.activeStream?.isQualityVerified, isTrue);
    });

    test('TEST 2: Sustained buffering on 1080p automatically switches to 720p', () {
      final tvOne = buildTvOneChannels().first;
      final tiss = TissController(
        config: const TissConfig(rebufferThreshold: 2, detectionWindowSeconds: 20),
      );
      final alt1080 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.fhd1080);
      tiss.attachLogicalChannel(tvOne, initialStream: alt1080, autoMode: true);

      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      expect(tiss.recordRebufferAndShouldFailover(now: t0), isFalse);
      expect(
        tiss.recordRebufferAndShouldFailover(
            now: t0.add(const Duration(seconds: 5))),
        isTrue,
      );

      // Observed throughput ~4.5 Mbps (80% safety margin = 3.6 Mbps) → picks 720p (3.5 Mbps)
      final next = tiss.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 4500,
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(next, isNotNull);
      expect(next!.tier, StreamQualityTier.hd720);
      expect(tiss.activeStream?.tier, StreamQualityTier.hd720);
    });

    test('TEST 3: When 720p also becomes unstable, switches to 480p', () {
      final tvOne = buildTvOneChannels().first;
      final tiss = TissController();
      final alt1080 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.fhd1080);
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      tiss.attachLogicalChannel(tvOne, initialStream: alt1080, now: t0);

      // 1080p -> 720p
      final firstSwitch = tiss.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 4500,
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(firstSwitch?.tier, StreamQualityTier.hd720);

      // 720p -> 480p when bandwidth drops to 2 Mbps
      final secondSwitch = tiss.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 2000,
        now: t0.add(const Duration(seconds: 15)),
      );
      expect(secondSwitch?.tier, StreamQualityTier.sd480);
    });

    test('TEST 4: Improved network waits for stability then upgrades to 1080p', () {
      final tvOne = buildTvOneChannels().first;
      final tiss = TissController(
        config: const TissConfig(
          stabilityPeriodSeconds: 30,
          upgradeCooldownSeconds: 40,
          failureCooldownSeconds: 20,
        ),
      );
      final alt1080 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.fhd1080);
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      tiss.attachLogicalChannel(tvOne, initialStream: alt1080, now: t0);

      // Failover 1080p -> 720p
      final down = tiss.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 4500,
        now: t0,
      );
      expect(down?.tier, StreamQualityTier.hd720);

      // Confirm 720p playback at t+2s
      tiss.confirmPlayback(
        startupMs: 800,
        width: 1280,
        height: 720,
        now: t0.add(const Duration(seconds: 2)),
      );

      // Too early (t+15s) → hysteresis blocks premature upgrade
      expect(
        tiss.evaluateQualityUpgrade(
          throughputKbps: 12000,
          bufferDuration: const Duration(seconds: 10),
          now: t0.add(const Duration(seconds: 15)),
        ),
        isNull,
      );

      // After stability + cooldown + failure expiry (t+60s) with 12 Mbps → upgrades to 1080p!
      final up = tiss.evaluateQualityUpgrade(
        throughputKbps: 12000,
        bufferDuration: const Duration(seconds: 10),
        now: t0.add(const Duration(seconds: 60)),
      );
      expect(up, isNotNull);
      expect(up!.tier, StreamQualityTier.fhd1080);
    });

    test('TEST 5: Expired 1080p stream fails over without retrying expired URL', () {
      final tvOne = buildTvOneChannels().first;
      final tiss = TissController();
      final alt1080 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.fhd1080);
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      tiss.attachLogicalChannel(tvOne, initialStream: alt1080, now: t0);

      final next = tiss.selectFailoverAlternative(
        reason: 'expired_token',
        isExpired: true,
        now: t0,
      );
      expect(next, isNotNull);
      expect(next!.streamId, isNot(alt1080.streamId));
      // Expired stream is temporarily excluded
      expect(tiss.healthRegistry.isAvailable(alt1080.streamId, now: t0), isFalse);
      // But recovers after cooldown expires (never permanently blacklisted)
      expect(
        tiss.healthRegistry.isAvailable(
          alt1080.streamId,
          now: t0.add(const Duration(minutes: 15)),
        ),
        isTrue,
      );
    });

    test('TEST 6: Different regional feeds are never grouped or switched into', () {
      final groups = ChannelGroupingEngine.groupChannels([
        _liveRow(
          id: 10,
          providerId: 'tv1_uk_1080',
          title: 'UK: TV ONE 1080P',
          url: 'http://provider.test/uk/1080.m3u8',
        ),
        _liveRow(
          id: 11,
          providerId: 'tv1_us_720',
          title: 'US: TV ONE 720P',
          url: 'http://provider.test/us/720.m3u8',
        ),
        _liveRow(
          id: 12,
          providerId: 'tv1_uk_plus1',
          title: 'UK: TV ONE +1 720P',
          url: 'http://provider.test/uk/plus1.m3u8',
        ),
      ]);

      // Must remain 3 distinct logical channels!
      expect(groups.length, 3);
      for (final g in groups) {
        expect(g.alternatives.length, 1);
      }
    });

    test('TEST 7: All alternatives unavailable returns null so UI shows error', () {
      final groups = ChannelGroupingEngine.groupChannels([
        _liveRow(
          id: 20,
          providerId: 'ch_hd',
          title: 'NEWS 1080P',
          url: 'http://provider.test/news_1080.m3u8',
        ),
        _liveRow(
          id: 21,
          providerId: 'ch_sd',
          title: 'NEWS 480P',
          url: 'http://provider.test/news_480.m3u8',
        ),
      ]);
      final news = groups.first;
      final tiss = TissController();
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      tiss.attachLogicalChannel(news, now: t0);

      // First failover succeeds (1080p -> 480p)
      final fallback = tiss.selectFailoverAlternative(reason: 'error', now: t0);
      expect(fallback?.tier, StreamQualityTier.sd480);

      // Second failover: no alternatives remain
      final exhausted = tiss.selectFailoverAlternative(
        reason: 'error',
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(exhausted, isNull);
    });

    test('TEST 8: Switching between logical channels selects correct group', () {
      final groups = ChannelGroupingEngine.groupChannels([
        _liveRow(
            id: 1,
            providerId: 'a_1080',
            title: 'ALPHA 1080P',
            url: 'http://p.test/a1080.m3u8'),
        _liveRow(
            id: 2,
            providerId: 'a_720',
            title: 'ALPHA 720P',
            url: 'http://p.test/a720.m3u8'),
        _liveRow(
            id: 3,
            providerId: 'b_1080',
            title: 'BETA 1080P',
            url: 'http://p.test/b1080.m3u8'),
        _liveRow(
            id: 4,
            providerId: 'b_480',
            title: 'BETA 480P',
            url: 'http://p.test/b480.m3u8'),
      ]);
      expect(groups.length, 2);

      final tiss = TissController();
      tiss.attachLogicalChannel(groups[0]);
      expect(tiss.activeChannel?.displayName, 'ALPHA');
      expect(tiss.activeChannel?.alternatives.length, 2);

      tiss.attachLogicalChannel(groups[1]);
      expect(tiss.activeChannel?.displayName, 'BETA');
      expect(tiss.activeStream?.streamUrl, 'http://p.test/b1080.m3u8');
    });

    test('TEST 9: Manual 480p preference prevents automatic quality upgrades', () {
      final tvOne = buildTvOneChannels().first;
      final tiss = TissController(
        config: const TissConfig(
          stabilityPeriodSeconds: 10,
          upgradeCooldownSeconds: 10,
        ),
      );
      final t0 = DateTime(2026, 11, 22, 10, 0, 0);
      tiss.attachLogicalChannel(tvOne, now: t0);

      final alt480 = tvOne.alternatives
          .firstWhere((a) => a.tier == StreamQualityTier.sd480);
      tiss.setManualQuality(alt480, now: t0);
      expect(tiss.isAutoMode, isFalse);

      // Even with 25 Mbps and long stability, manual 480p must be respected!
      final upgrade = tiss.evaluateQualityUpgrade(
        throughputKbps: 25000,
        bufferDuration: const Duration(seconds: 20),
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(upgrade, isNull);
      expect(tiss.activeStream?.tier, StreamQualityTier.sd480);
    });

    test('TEST 10: Diagnostics redacts stream URLs & supports manual split/merge', () {
      final rows = [
        _liveRow(
            id: 1,
            providerId: 'p1',
            title: 'SPORT 1080P',
            url: 'http://user:secret@iptv.example.com/live/u/p/1.m3u8'),
        _liveRow(
            id: 2,
            providerId: 'p2',
            title: 'SPORT 720P',
            url: 'http://user:secret@iptv.example.com/live/u/p/2.m3u8'),
      ];

      // Manual split separates p2 into its own standalone channel
      final splitGroups = ChannelGroupingEngine.groupChannels(
        rows,
        manualSplits: {'p2'},
      );
      expect(splitGroups.length, 2);

      // Diagnostics redacts credentials/tokens
      final grouped = ChannelGroupingEngine.groupChannels(rows).first;
      final tiss = TissController();
      tiss.attachLogicalChannel(grouped);
      final diag = tiss.diagnosticsSnapshot();
      expect(diag.logicalChannelName, 'SPORT');
      expect(diag.activeStreamRedactedId, isNotNull);
      expect(diag.activeStreamRedactedId!.contains('secret'), isFalse);
    });
  });
}
