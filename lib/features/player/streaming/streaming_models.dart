import '../domain/playback_enums.dart';

/// Three primary buffering profiles for IPTV playback.
enum BufferProfile {
  lowLatency,
  balanced,
  stable,
}

extension BufferProfileLabel on BufferProfile {
  String get label => switch (this) {
        BufferProfile.lowLatency => 'Low Latency',
        BufferProfile.balanced => 'Balanced',
        BufferProfile.stable => 'Stable',
      };

  String get description => switch (this) {
        BufferProfile.lowLatency =>
          'Fastest startup & channel switching with a compact buffer.',
        BufferProfile.balanced =>
          'Adaptive balance between fast zapping and smooth playback.',
        BufferProfile.stable =>
          'Larger buffer for weak Wi-Fi, mobile data, or unstable streams.',
      };

  PlaybackProfile toLegacyProfile() => switch (this) {
        BufferProfile.lowLatency => PlaybackProfile.dataSaver,
        BufferProfile.balanced => PlaybackProfile.auto,
        BufferProfile.stable => PlaybackProfile.moreStable,
      };

  static BufferProfile fromLegacyProfile(PlaybackProfile profile) =>
      switch (profile) {
        PlaybackProfile.dataSaver => BufferProfile.lowLatency,
        PlaybackProfile.auto => BufferProfile.balanced,
        PlaybackProfile.moreStable => BufferProfile.stable,
        PlaybackProfile.highQuality => BufferProfile.balanced,
      };
}

/// Platform- and stream-type-aware buffer parameters.
class BufferConfig {
  final BufferProfile profile;
  final int readaheadSecs;
  final int cacheSecs;
  final int demuxerMaxBytes;
  final int demuxerMaxBackBytes;
  final double cachePauseWaitSecs;
  final int networkTimeoutSecs;
  final int vlcNetworkCachingMs;
  final int stallTimeoutSecs;
  final int bufferingTimeoutSecs;

  const BufferConfig({
    required this.profile,
    required this.readaheadSecs,
    required this.cacheSecs,
    required this.demuxerMaxBytes,
    required this.demuxerMaxBackBytes,
    required this.cachePauseWaitSecs,
    required this.networkTimeoutSecs,
    required this.vlcNetworkCachingMs,
    required this.stallTimeoutSecs,
    required this.bufferingTimeoutSecs,
  });

  /// Computes bounded, memory-safe buffer targets based on profile, stream type
  /// (live vs VOD), and whether the device is memory-constrained (mobile/TV).
  factory BufferConfig.resolve({
    required BufferProfile profile,
    required bool isLive,
    required bool isLowMemoryDevice,
  }) {
    final memScale = isLowMemoryDevice ? 0.5 : 1.0;

    switch (profile) {
      case BufferProfile.lowLatency:
        return BufferConfig(
          profile: profile,
          readaheadSecs: isLive ? 3 : 10,
          cacheSecs: isLive ? 8 : 20,
          demuxerMaxBytes: (24 * 1024 * 1024 * memScale).round(),
          demuxerMaxBackBytes: (6 * 1024 * 1024 * memScale).round(),
          cachePauseWaitSecs: isLive ? 0.5 : 1.0,
          networkTimeoutSecs: 12,
          vlcNetworkCachingMs: isLive ? 700 : 1200,
          stallTimeoutSecs: 10,
          bufferingTimeoutSecs: 12,
        );
      case BufferProfile.balanced:
        return BufferConfig(
          profile: profile,
          readaheadSecs: isLive ? 8 : 25,
          cacheSecs: isLive ? 20 : 45,
          demuxerMaxBytes: (48 * 1024 * 1024 * memScale).round(),
          demuxerMaxBackBytes: (12 * 1024 * 1024 * memScale).round(),
          cachePauseWaitSecs: isLive ? 1.5 : 2.0,
          networkTimeoutSecs: 18,
          vlcNetworkCachingMs: isLive ? 1500 : 2500,
          stallTimeoutSecs: 14,
          bufferingTimeoutSecs: 16,
        );
      case BufferProfile.stable:
        return BufferConfig(
          profile: profile,
          readaheadSecs: isLive ? 18 : 60,
          cacheSecs: isLive ? 45 : 90,
          demuxerMaxBytes: (80 * 1024 * 1024 * memScale).round(),
          demuxerMaxBackBytes: (16 * 1024 * 1024 * memScale).round(),
          cachePauseWaitSecs: isLive ? 3.0 : 3.5,
          networkTimeoutSecs: 25,
          vlcNetworkCachingMs: isLive ? 3200 : 4500,
          stallTimeoutSecs: 18,
          bufferingTimeoutSecs: 22,
        );
    }
  }
}

/// Specific failure categories so the UI never blames every error on "buffering".
enum StreamFailureKind {
  none,
  invalidUrl,
  expiredOrUnauthorized,
  streamUnavailable,
  networkError,
  unsupportedFormat,
  decoderError,
}

/// A single ABR video rendition parsed from an HLS master playlist or DASH MPD.
class StreamRendition {
  final String id;
  final String label;
  final int bandwidthBps;
  final int? width;
  final int? height;
  final String? codecs;
  final String? uri;

  const StreamRendition({
    required this.id,
    required this.label,
    required this.bandwidthBps,
    this.width,
    this.height,
    this.codecs,
    this.uri,
  });

  static const auto = StreamRendition(
    id: 'auto',
    label: 'Auto (Adaptive)',
    bandwidthBps: 0,
  );

  bool get isAuto => id == 'auto';
}

/// Result of pre-playback stream validation.
class StreamValidationResult {
  final bool isValid;
  final StreamFailureKind failureKind;
  final String? userMessage;
  final int? httpStatusCode;
  final String? contentType;
  final bool supportsAbr;
  final List<StreamRendition> renditions;

  const StreamValidationResult({
    required this.isValid,
    this.failureKind = StreamFailureKind.none,
    this.userMessage,
    this.httpStatusCode,
    this.contentType,
    this.supportsAbr = false,
    this.renditions = const [],
  });

  const StreamValidationResult.valid({
    this.httpStatusCode,
    this.contentType,
    this.supportsAbr = false,
    this.renditions = const [],
  })  : isValid = true,
        failureKind = StreamFailureKind.none,
        userMessage = null;

  const StreamValidationResult.failed({
    required this.failureKind,
    required this.userMessage,
    this.httpStatusCode,
    this.contentType,
  })  : isValid = false,
        supportsAbr = false,
        renditions = const [];
}

/// Point-in-time streaming telemetry exposed to the Diagnostics Panel.
class StreamingAnalyticsSnapshot {
  final int? lastStartupMs;
  final int? averageStartupMs;
  final int? lastChannelSwitchMs;
  final int rebufferCount;
  final int totalBufferingMs;
  final int droppedFrames;
  final int? estimatedThroughputKbps;
  final String selectedQualityLabel;
  final bool supportsAbr;
  final int recoveryAttempts;
  final int recoverySuccesses;
  final StreamFailureKind lastFailureKind;
  final String? rootCauseHint;
  final List<String> recentEvents;

  const StreamingAnalyticsSnapshot({
    this.lastStartupMs,
    this.averageStartupMs,
    this.lastChannelSwitchMs,
    this.rebufferCount = 0,
    this.totalBufferingMs = 0,
    this.droppedFrames = 0,
    this.estimatedThroughputKbps,
    this.selectedQualityLabel = 'Fixed quality (ABR N/A)',
    this.supportsAbr = false,
    this.recoveryAttempts = 0,
    this.recoverySuccesses = 0,
    this.lastFailureKind = StreamFailureKind.none,
    this.rootCauseHint,
    this.recentEvents = const [],
  });

  double get recoverySuccessRate =>
      recoveryAttempts == 0 ? 1.0 : recoverySuccesses / recoveryAttempts;
}
