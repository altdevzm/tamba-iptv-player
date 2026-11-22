import 'tiss_models.dart';

/// Local stream health & failure history registry.
///
/// Tracks per-stream reliability, temporary failure cooldowns, and verified
/// playback dimensions. Failure records always expire automatically so a
/// temporarily unavailable source is never permanently blacklisted.
class StreamHealthRegistry {
  final Map<String, StreamHealthRecord> _records = {};
  final Map<String, ({int width, int height, String? codec, int? bitrateKbps})>
      _verifiedDimensions = {};

  StreamHealthRecord? getRecord(String streamId) => _records[streamId];

  bool isAvailable(String streamId, {DateTime? now}) {
    final record = _records[streamId];
    if (record == null) return true;
    return !record.isTemporarilyExcluded(now ?? DateTime.now());
  }

  double reliabilityScore(String streamId) =>
      _records[streamId]?.reliabilityScore ?? 0.90;

  void recordSuccess(
    String streamId,
    String logicalChannelId, {
    int? startupMs,
    bool wasRecovery = false,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final prev = _records[streamId] ??
        StreamHealthRecord(
          streamId: streamId,
          logicalChannelId: logicalChannelId,
        );
    _records[streamId] = prev.copyWith(
      lastSuccessfulPlayback: ts,
      lastStartupMs: startupMs ?? prev.lastStartupMs,
      consecutiveFailures: 0,
      isExpired: false,
      recoverySuccesses:
          wasRecovery ? prev.recoverySuccesses + 1 : prev.recoverySuccesses,
      clearCooldown: true,
    );
  }

  void recordBuffering(String streamId, String logicalChannelId) {
    final prev = _records[streamId] ??
        StreamHealthRecord(
          streamId: streamId,
          logicalChannelId: logicalChannelId,
        );
    _records[streamId] = prev.copyWith(
      bufferingEvents: prev.bufferingEvents + 1,
    );
  }

  void recordFailure(
    String streamId,
    String logicalChannelId, {
    bool isExpired = false,
    TissConfig config = const TissConfig(),
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final prev = _records[streamId] ??
        StreamHealthRecord(
          streamId: streamId,
          logicalChannelId: logicalChannelId,
        );
    final cooldownSecs = isExpired
        ? config.expiredCooldownSeconds
        : config.failureCooldownSeconds;
    _records[streamId] = prev.copyWith(
      lastFailureAt: ts,
      errorCount: prev.errorCount + 1,
      consecutiveFailures: prev.consecutiveFailures + 1,
      isExpired: isExpired,
      cooldownUntil: ts.add(Duration(seconds: cooldownSecs)),
    );
  }

  void recordVerifiedQuality(
    String streamId, {
    required int width,
    required int height,
    String? codec,
    int? bitrateKbps,
  }) {
    if (width <= 0 || height <= 0) return;
    _verifiedDimensions[streamId] = (
      width: width,
      height: height,
      codec: codec,
      bitrateKbps: bitrateKbps,
    );
  }

  StreamAlternative applyVerifiedQuality(StreamAlternative alt) {
    final info = _verifiedDimensions[alt.streamId];
    if (info == null) return alt;
    final verifiedTier = StreamQualityTierInfo.fromHeight(info.height);
    return alt.copyWith(
      verifiedWidth: info.width,
      verifiedHeight: info.height,
      isQualityVerified: true,
      qualitySource: QualitySource.playbackReported,
      tier: verifiedTier,
      displayQuality: verifiedTier.shortLabel,
      codec: info.codec ?? alt.codec,
      estimatedBitrateKbps: info.bitrateKbps ?? alt.estimatedBitrateKbps,
    );
  }

  List<StreamHealthRecord> failedRecordsForChannel(
    String logicalChannelId, {
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return _records.values
        .where((r) =>
            r.logicalChannelId == logicalChannelId &&
            r.isTemporarilyExcluded(ts))
        .toList();
  }

  void clear() {
    _records.clear();
    _verifiedDimensions.clear();
  }
}
