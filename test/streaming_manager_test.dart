import 'package:flutter_test/flutter_test.dart';

import 'package:filimu_plus/features/player/streaming/stream_validator.dart';
import 'package:filimu_plus/features/player/streaming/streaming_analytics.dart';
import 'package:filimu_plus/features/player/streaming/streaming_manager.dart';
import 'package:filimu_plus/features/player/streaming/streaming_models.dart';

void main() {
  group('StreamValidator', () {
    test('redacts credentials and sensitive path segments from URLs', () {
      const secretUrl =
          'http://user:pass@iptv.example.com:8080/live/secretUser/secretPass/12345.m3u8?token=abc';
      final redacted = StreamValidator.redactUrl(secretUrl);
      expect(redacted, 'http://iptv.example.com/•••.m3u8');
      expect(redacted.contains('secretUser'), isFalse);
      expect(redacted.contains('secretPass'), isFalse);
      expect(redacted.contains('abc'), isFalse);
    });

    test('parses HLS master playlist renditions for ABR', () {
      const master = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2"
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3200000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
med/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
high/index.m3u8
''';

      final renditions = StreamValidator.parseHlsMasterRenditions(
        master,
        baseUri: Uri.parse('https://cdn.example.com/live/master.m3u8'),
      );

      expect(renditions.length, 3);
      // Sorted highest bitrate first
      expect(renditions[0].height, 1080);
      expect(renditions[0].bandwidthBps, 6000000);
      expect(renditions[0].uri, 'https://cdn.example.com/live/high/index.m3u8');
      expect(renditions[2].height, 360);
    });

    test('does not claim ABR for single-rendition media playlists', () {
      const mediaPlaylist = '''#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
seg001.ts
#EXTINF:6.0,
seg002.ts
''';
      final renditions = StreamValidator.parseHlsMasterRenditions(mediaPlaylist);
      expect(renditions, isEmpty);
    });

    test('rejects empty or malformed URLs before opening player', () async {
      const validator = StreamValidator();
      final empty = await validator.validate('');
      expect(empty.isValid, isFalse);
      expect(empty.failureKind, StreamFailureKind.invalidUrl);

      final bad = await validator.validate('not_a_valid_url');
      expect(bad.isValid, isFalse);
      expect(bad.failureKind, StreamFailureKind.invalidUrl);
    });

    test('classifies player errors accurately', () {
      expect(
        StreamValidator.classifyPlayerError('HTTP 403 Forbidden'),
        StreamFailureKind.expiredOrUnauthorized,
      );
      expect(
        StreamValidator.classifyPlayerError('HTTP 404 Not Found'),
        StreamFailureKind.streamUnavailable,
      );
      expect(
        StreamValidator.classifyPlayerError('Could not recognize stream format'),
        StreamFailureKind.unsupportedFormat,
      );
      expect(
        StreamValidator.classifyPlayerError('Connection timed out'),
        StreamFailureKind.networkError,
      );
    });
  });

  group('BufferConfig & StreamingManager', () {
    test('scales buffer targets across Low Latency, Balanced, and Stable', () {
      final low = BufferConfig.resolve(
        profile: BufferProfile.lowLatency,
        isLive: true,
        isLowMemoryDevice: false,
      );
      final balanced = BufferConfig.resolve(
        profile: BufferProfile.balanced,
        isLive: true,
        isLowMemoryDevice: false,
      );
      final stable = BufferConfig.resolve(
        profile: BufferProfile.stable,
        isLive: true,
        isLowMemoryDevice: false,
      );

      expect(low.readaheadSecs, lessThan(balanced.readaheadSecs));
      expect(balanced.readaheadSecs, lessThan(stable.readaheadSecs));
      expect(low.vlcNetworkCachingMs, lessThan(balanced.vlcNetworkCachingMs));
      expect(balanced.vlcNetworkCachingMs, lessThan(stable.vlcNetworkCachingMs));

      // Low-memory devices halve demuxer memory cap
      final lowMem = BufferConfig.resolve(
        profile: BufferProfile.stable,
        isLive: true,
        isLowMemoryDevice: true,
      );
      expect(lowMem.demuxerMaxBytes, lessThan(stable.demuxerMaxBytes));
    });

    test('builds mpv properties with FFmpeg reconnect and bounded cache', () {
      final manager = StreamingManager();
      manager.setBufferProfile(BufferProfile.lowLatency);
      final props = manager.buildMpvProperties(isLive: true, isAndroid: false);
      expect(props['cache'], 'yes');
      expect(props['demuxer-lavf-o'], contains('reconnect=1'));
      expect(props['network-timeout'], isNotNull);
    });

    test('provides exponential backoff delays capped at max attempts', () {
      final manager = StreamingManager();
      expect(manager.backoffDelayForAttempt(0), 1);
      expect(manager.backoffDelayForAttempt(1), 2);
      expect(manager.backoffDelayForAttempt(2), 4);
      expect(manager.backoffDelayForAttempt(3), 8);
      expect(manager.backoffDelayForAttempt(4), 15);
      expect(manager.backoffDelayForAttempt(99), 15);
    });
  });

  group('StreamingAnalytics', () {
    test('records TTFF, rebuffers, and recovery success rate', () async {
      final analytics = StreamingAnalytics();
      analytics.recordPlaybackStart(isChannelSwitch: true);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      analytics.recordFirstFrame();

      analytics.recordBufferingChanged(true, hasStarted: true);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      analytics.recordBufferingChanged(false, hasStarted: true);

      analytics.recordRecoveryAttempt(1, 'networkError');
      analytics.recordRecoverySuccess();

      final snap = analytics.snapshot();
      expect(snap.lastStartupMs, isNotNull);
      expect(snap.lastStartupMs!, greaterThanOrEqualTo(10));
      expect(snap.lastChannelSwitchMs, isNotNull);
      expect(snap.rebufferCount, 1);
      expect(snap.totalBufferingMs, greaterThanOrEqualTo(10));
      expect(snap.recoverySuccessRate, 1.0);
    });
  });
}
