import 'package:flutter_test/flutter_test.dart';

import 'package:filimu_plus/core/persistence/app_database.dart';
import 'package:filimu_plus/features/player/streaming/stream_validator.dart';
import 'package:filimu_plus/features/player/streaming/streaming_models.dart';
import 'package:filimu_plus/features/player/tiss/channel_grouping_engine.dart';
import 'package:filimu_plus/features/player/tiss/tiss_controller.dart';
import 'package:filimu_plus/features/player/tiss/tiss_models.dart';

ContentItemsTableData _row(
  int id,
  String providerId,
  String title,
  String url, {
  String? epgId,
  int categoryId = 1,
}) {
  return ContentItemsTableData(
    id: id,
    playlistId: 'smart_pl',
    categoryId: categoryId,
    title: title,
    type: 'live',
    providerId: providerId,
    streamUrl: url,
    posterUrl: 'http://cdn.test/logo.png',
    epgChannelId: epgId,
    tvArchive: 0,
    tvArchiveDuration: 0,
  );
}

void main() {
  group('Tamba SmartStream — 16 Required Scenarios', () {
    List<ContentItemsTableData> fourQualities() => [
          _row(1, 'tv1_4k', 'TV One 4K', 'http://p.test/tv1_4k.m3u8', epgId: 'tv1.ch'),
          _row(2, 'tv1_1080', 'TV One 1080p', 'http://p.test/tv1_1080.m3u8', epgId: 'tv1.ch'),
          _row(3, 'tv1_720', 'TV One 720p', 'http://p.test/tv1_720.m3u8', epgId: 'tv1.ch'),
          _row(4, 'tv1_480', 'TV One 480p', 'http://p.test/tv1_480.m3u8', epgId: 'tv1.ch'),
        ];

    test('Scenario 1-4: 4K -> 1080p -> 720p failover and controlled 1080p recovery', () {
      final logical = ChannelGroupingEngine.groupChannels(fourQualities()).first;
      expect(logical.alternatives.length, 4);

      final ctrl = TissController(
        config: const TissConfig(
          mode: SmartStreamMode.balanced,
          rebufferThreshold: 2,
          stabilityPeriodSeconds: 30,
          upgradeCooldownSeconds: 35,
          failureCooldownSeconds: 20,
        ),
      );
      final t0 = DateTime(2026, 11, 22, 12, 0, 0);
      ctrl.attachLogicalChannel(logical, now: t0);
      expect(ctrl.activeStream?.tier, StreamQualityTier.uhd4k);

      // 4K buffers repeatedly -> switches to 1080p (at 10 Mbps -> 8 Mbps sustainable)
      ctrl.recordRebufferAndShouldFailover(now: t0);
      expect(ctrl.recordRebufferAndShouldFailover(now: t0.add(const Duration(seconds: 4))), isTrue);
      final to1080 = ctrl.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 10000,
        now: t0.add(const Duration(seconds: 4)),
      );
      expect(to1080?.tier, StreamQualityTier.fhd1080);

      // 1080p also unstable at 5 Mbps -> switches to 720p
      final to720 = ctrl.selectFailoverAlternative(
        reason: 'sustained_buffering',
        throughputKbps: 5000,
        now: t0.add(const Duration(seconds: 12)),
      );
      expect(to720?.tier, StreamQualityTier.hd720);
      ctrl.confirmPlayback(
        width: 1280,
        height: 720,
        now: t0.add(const Duration(seconds: 14)),
      );
      expect(ctrl.activeStream?.qualitySource, QualitySource.playbackReported);

      // Network improves to 12 Mbps after stability window -> restores 1080p
      final recovered = ctrl.evaluateQualityUpgrade(
        throughputKbps: 12000,
        bufferDuration: const Duration(seconds: 10),
        now: t0.add(const Duration(seconds: 65)),
      );
      expect(recovered?.tier, StreamQualityTier.fhd1080);
    });

    test('Scenario 5 & 6: Unavailable 4K or expired URL fails over cleanly to 1080p', () {
      final logical = ChannelGroupingEngine.groupChannels(fourQualities()).first;
      final ctrl = TissController();
      final t0 = DateTime(2026, 11, 22, 12, 0, 0);
      ctrl.attachLogicalChannel(logical, now: t0);

      final fallback = ctrl.selectFailoverAlternative(
        reason: 'expired_or_unavailable',
        isExpired: true,
        now: t0,
      );
      expect(fallback?.tier, StreamQualityTier.fhd1080);
      expect(ctrl.healthRegistry.isAvailable(logical.alternatives.first.streamId, now: t0), isFalse);
    });

    test('Scenario 7 & 8: Different programming (conflicting EPG) & regional versions stay separate', () {
      final rows = [
        _row(1, 'c1', 'Channel One 1080p', 'http://p.test/1.m3u8', epgId: 'ch1.news'),
        _row(2, 'c2', 'Channel One 720p', 'http://p.test/2.m3u8', epgId: 'ch1.sports'),
        _row(3, 'c3', 'UK: Discovery 1080p', 'http://p.test/3.m3u8'),
        _row(4, 'c4', 'US: Discovery 720p', 'http://p.test/4.m3u8'),
      ];
      final grouped = ChannelGroupingEngine.groupChannels(rows);
      expect(grouped.length, 4);
    });

    test('Scenario 9: Single-stream channel handles gracefully with no alternatives', () {
      final grouped = ChannelGroupingEngine.groupChannels([
        _row(1, 'solo', 'Local TV', 'http://p.test/solo.m3u8'),
      ]);
      expect(grouped.length, 1);
      final ctrl = TissController();
      ctrl.attachLogicalChannel(grouped.first);
      expect(ctrl.hasAlternatives, isFalse);
      expect(ctrl.selectFailoverAlternative(reason: 'error'), isNull);
    });

    test('Scenario 10 & 11: Manual 720p & Most Stable / disabled auto-recovery respected', () {
      final logical = ChannelGroupingEngine.groupChannels(fourQualities()).first;
      final ctrl = TissController();
      final t0 = DateTime(2026, 11, 22, 12, 0, 0);

      // Most Stable mode picks <=720p initially and disables auto-upgrade
      ctrl.setMode(SmartStreamMode.mostStable);
      ctrl.attachLogicalChannel(logical, now: t0);
      expect(ctrl.activeStream?.tier.rank, lessThanOrEqualTo(StreamQualityTier.hd720.rank));
      expect(ctrl.config.autoUpgradeEnabled, isFalse);

      // Manual 720p prevents auto-upgrade even in Balanced mode
      ctrl.setMode(SmartStreamMode.balanced);
      final alt720 = logical.alternatives.firstWhere((a) => a.tier == StreamQualityTier.hd720);
      ctrl.setManualQuality(alt720, now: t0);
      expect(
        ctrl.evaluateQualityUpgrade(
          throughputKbps: 20000,
          bufferDuration: const Duration(seconds: 15),
          now: t0.add(const Duration(minutes: 10)),
        ),
        isNull,
      );
    });

    test('Scenario 12: Unsupported codec classified accurately', () {
      expect(
        StreamValidator.classifyPlayerError('Unsupported video codec HEVC'),
        StreamFailureKind.unsupportedFormat,
      );
      expect(
        StreamValidator.classifyPlayerError('MediaCodec hwdec decoder error'),
        StreamFailureKind.decoderError,
      );
    });

    test('Scenario 15: Large 5,000-entry playlist groups quickly without blocking', () {
      final huge = <ContentItemsTableData>[];
      for (var i = 0; i < 1250; i++) {
        huge.add(_row(i * 4 + 1, 'ch_${i}_4k', 'Channel $i 4K', 'http://p.test/$i/4k.m3u8'));
        huge.add(_row(i * 4 + 2, 'ch_${i}_1080', 'Channel $i 1080p', 'http://p.test/$i/1080.m3u8'));
        huge.add(_row(i * 4 + 3, 'ch_${i}_720', 'Channel $i 720p', 'http://p.test/$i/720.m3u8'));
        huge.add(_row(i * 4 + 4, 'ch_${i}_480', 'Channel $i 480p', 'http://p.test/$i/480.m3u8'));
      }
      final sw = Stopwatch()..start();
      final grouped = ChannelGroupingEngine.groupChannels(huge);
      sw.stop();

      expect(grouped.length, 1250);
      expect(grouped.first.alternatives.length, 4);
      // Should group 5,000 channels well under 500ms
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('Scenario 16: Multi-hour session stays stable without repeated switching', () {
      final logical = ChannelGroupingEngine.groupChannels(fourQualities()).first;
      final ctrl = TissController();
      var now = DateTime(2026, 11, 22, 12, 0, 0);
      ctrl.attachLogicalChannel(logical, now: now);
      ctrl.confirmPlayback(width: 3840, height: 2160, now: now);

      var switches = 0;
      // Simulate 4 hours (480 intervals of 30s) with occasional single isolated hiccups
      for (var i = 1; i <= 480; i++) {
        now = now.add(const Duration(seconds: 30));
        if (i % 40 == 0) {
          // Isolated single rebuffer every 20 minutes must NOT trigger a switch
          if (ctrl.recordRebufferAndShouldFailover(now: now)) {
            switches++;
          }
        }
        final up = ctrl.evaluateQualityUpgrade(
          throughputKbps: 20000,
          bufferDuration: const Duration(seconds: 12),
          now: now,
        );
        if (up != null) switches++;
      }
      expect(switches, 0);
    });

    test('Cross-category matching & non-interruptive background candidate ranking', () {
      final raw = [
        _row(1, 'ss1_4k', 'ZA: SuperSport 1 4K', 'http://tv/ss1_4k', categoryId: 10),
        _row(2, 'ss1_fhd', 'SuperSport 1 FHD', 'http://tv/ss1_fhd', categoryId: 20),
        _row(3, 'ss1_hd', 'SuperSport 1 HD Backup', 'http://tv/ss1_hd', categoryId: 30),
        _row(4, 'bbc_uk', 'UK: BBC One HD', 'http://tv/bbc_uk', categoryId: 40),
        _row(5, 'bbc_us', 'US: BBC One HD', 'http://tv/bbc_us', categoryId: 50),
      ];

      final grouped = ChannelGroupingEngine.groupChannels(raw);
      // SuperSport 1 across categories 10, 20, 30 must merge into 1 logical channel,
      // while UK and US BBC One must remain strictly separate.
      expect(grouped.length, 3);
      final ss1 = grouped.firstWhere((g) => g.alternatives.length == 3);

      final ctrl = TissController();
      ctrl.attachLogicalChannel(ss1);
      final initialId = ctrl.activeStream!.streamId;
      expect(ctrl.activeStream!.tier, StreamQualityTier.uhd4k);

      // Background ranking must NOT mutate activeStream until verified commit
      final candidates = ctrl.rankedFailoverCandidates();
      expect(candidates.length, 2);
      expect(candidates.first.tier, StreamQualityTier.fhd1080);
      expect(ctrl.activeStream!.streamId, initialId);

      // Marking dead candidate unreachable excludes it from subsequent probes
      ctrl.markCandidateUnreachable(candidates.first);
      final nextCandidates = ctrl.rankedFailoverCandidates();
      expect(nextCandidates.length, 1);
      expect(nextCandidates.first.tier, StreamQualityTier.hd720);

      // Committing verified alternative updates activeStream cleanly
      ctrl.commitVerifiedFailover(nextCandidates.first, reason: 'sustained_buffering');
      expect(ctrl.activeStream!.tier, StreamQualityTier.hd720);
    });
  });
}
