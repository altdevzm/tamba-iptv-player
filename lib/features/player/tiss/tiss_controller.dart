import '../streaming/stream_validator.dart';
import 'stream_health_registry.dart';
import 'tiss_models.dart';

/// Orchestrates Tamba Intelligent Stream Switching (TISS):
/// - Automatic Failover Engine (downgrades to sustainable alternative on
///   sustained buffering, stalls, or stream/expired-URL failures)
/// - Intelligent Alternative Selection (bandwidth safety margin + reliability)
/// - QualityRecoveryController (gradual, hysteresis-guarded upgrades when
///   network improves)
/// - Manual Quality Control (Auto vs pinned quality preference)
class TissController {
  final StreamHealthRegistry healthRegistry;
  TissConfig _config;

  LogicalChannel? _activeChannel;
  StreamAlternative? _activeStream;
  StreamAlternative? _preferredStream;
  bool _isAutoMode = true;

  final List<DateTime> _recentRebuffers = [];
  DateTime? _stablePlaybackSince;
  DateTime? _lastSwitchAt;
  DateTime? _failoverStartedAt;
  TissFailoverEvent? _lastFailoverEvent;
  int _successfulRecoveries = 0;

  TissController({
    StreamHealthRegistry? healthRegistry,
    TissConfig config = const TissConfig(),
  })  : healthRegistry = healthRegistry ?? StreamHealthRegistry(),
        _config = config;

  TissConfig get config => _config;
  LogicalChannel? get activeChannel => _activeChannel;
  StreamAlternative? get activeStream => _activeStream;
  bool get isAutoMode => _isAutoMode;
  bool get hasAlternatives => (_activeChannel?.alternatives.length ?? 0) > 1;
  TissFailoverEvent? get lastFailoverEvent => _lastFailoverEvent;
  int get successfulRecoveries => _successfulRecoveries;

  void updateConfig(TissConfig newConfig) {
    _config = newConfig;
  }

  /// Applies a [SmartStreamMode] (`balanced`, `bestQuality`, `mostStable`),
  /// updating safety margins, rebuffer thresholds, and auto-upgrade behavior.
  void setMode(SmartStreamMode mode) {
    _config = TissConfig.forMode(
      mode,
      allowEmergencyFallbackInManualMode:
          _config.allowEmergencyFallbackInManualMode,
    ).copyWith(simulatePoorNetwork: _config.simulatePoorNetwork);
  }

  /// Selects the initial alternative for [channel] respecting the active
  /// [SmartStreamMode]: `mostStable` prefers a conservative ≤720p stream,
  /// `bestQuality` prefers the highest resolution, and `balanced` picks the
  /// highest healthy stream.
  StreamAlternative selectInitialStream(
    LogicalChannel channel, {
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final healthy = channel.alternatives
        .map(healthRegistry.applyVerifiedQuality)
        .where((a) => healthRegistry.isAvailable(a.streamId, now: ts))
        .toList();
    final pool = healthy.isNotEmpty ? healthy : channel.alternatives;

    if (_config.mode == SmartStreamMode.mostStable) {
      for (final alt in pool) {
        if (alt.tier.rank <= StreamQualityTier.hd720.rank) return alt;
      }
      return pool.last;
    }
    return pool.first;
  }

  /// Attaches a [LogicalChannel] when the user starts watching a channel.
  void attachLogicalChannel(
    LogicalChannel channel, {
    StreamAlternative? initialStream,
    bool autoMode = true,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    _activeChannel = channel;
    final chosen = initialStream ?? selectInitialStream(channel, now: ts);
    _activeStream = healthRegistry.applyVerifiedQuality(chosen);
    _preferredStream = _activeStream;
    _isAutoMode = autoMode;
    _recentRebuffers.clear();
    _stablePlaybackSince = ts;
    _failoverStartedAt = null;
  }

  void detach() {
    _activeChannel = null;
    _activeStream = null;
    _preferredStream = null;
    _recentRebuffers.clear();
    _stablePlaybackSince = null;
    _failoverStartedAt = null;
  }

  /// Switches between Auto mode (`alt == null`) and Manual quality mode.
  StreamAlternative? setManualQuality(StreamAlternative? alt, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    if (alt == null) {
      _isAutoMode = true;
      _stablePlaybackSince = ts;
      return _activeStream;
    }
    _isAutoMode = false;
    _activeStream = healthRegistry.applyVerifiedQuality(alt);
    _preferredStream = _activeStream;
    _recentRebuffers.clear();
    _stablePlaybackSince = ts;
    _lastSwitchAt = ts;
    return _activeStream;
  }

  /// Records verified dimensions/codec once the player actually renders video.
  void confirmPlayback({
    int? startupMs,
    int? width,
    int? height,
    String? codec,
    int? bitrateKbps,
    DateTime? now,
  }) {
    final channel = _activeChannel;
    final stream = _activeStream;
    if (channel == null || stream == null) return;
    final ts = now ?? DateTime.now();

    if (width != null && height != null && width > 0 && height > 0) {
      healthRegistry.recordVerifiedQuality(
        stream.streamId,
        width: width,
        height: height,
        codec: codec,
        bitrateKbps: bitrateKbps,
      );
      _activeStream = healthRegistry.applyVerifiedQuality(stream);
    }

    final wasRecovery = _failoverStartedAt != null;
    healthRegistry.recordSuccess(
      stream.streamId,
      channel.logicalId,
      startupMs: startupMs,
      wasRecovery: wasRecovery,
      now: ts,
    );

    if (wasRecovery) {
      final elapsed = ts.difference(_failoverStartedAt!).inMilliseconds;
      _successfulRecoveries++;
      if (_lastFailoverEvent != null) {
        _lastFailoverEvent = TissFailoverEvent(
          timestamp: ts,
          logicalChannelName: channel.displayName,
          fromQuality: _lastFailoverEvent!.fromQuality,
          toQuality: _activeStream!.displayQuality,
          reason: _lastFailoverEvent!.reason,
          recoveryDurationMs: elapsed,
          wasUpgrade: _lastFailoverEvent!.wasUpgrade,
          succeeded: true,
        );
      }
      _failoverStartedAt = null;
    }

    _stablePlaybackSince ??= ts;
  }

  /// Records a rebuffer event and returns `true` if sustained instability
  /// warrants an automatic failover to a lower-quality alternative.
  bool recordRebufferAndShouldFailover({DateTime? now}) {
    final channel = _activeChannel;
    final stream = _activeStream;
    if (channel == null || stream == null || !hasAlternatives) return false;
    if (!_isAutoMode || !_config.automaticSwitchingEnabled) return false;

    final ts = now ?? DateTime.now();
    healthRegistry.recordBuffering(stream.streamId, channel.logicalId);
    _stablePlaybackSince = null;

    _recentRebuffers.add(ts);
    final windowStart =
        ts.subtract(Duration(seconds: _config.detectionWindowSeconds));
    _recentRebuffers.removeWhere((t) => t.isBefore(windowStart));

    if (_config.simulatePoorNetwork) return true;
    return _recentRebuffers.length >= _config.rebufferThreshold;
  }

  /// Returns ranked failover candidates within the SAME [LogicalChannel]
  /// (across all categories of the playlist) WITHOUT mutating active playback
  /// state, so the player can probe them in the background without interrupting
  /// the user's current viewing experience.
  List<StreamAlternative> rankedFailoverCandidates({
    int? throughputKbps,
    bool isExpired = false,
    bool allowFallbackInManualMode = false,
    DateTime? now,
  }) {
    final channel = _activeChannel;
    final current = _activeStream;
    if (channel == null || current == null || channel.alternatives.length < 2) {
      return const [];
    }
    if (!_config.automaticSwitchingEnabled) return const [];
    if (!_isAutoMode && !allowFallbackInManualMode) return const [];

    final ts = now ?? DateTime.now();
    final effectiveThroughput =
        _config.simulatePoorNetwork ? 1500 : throughputKbps;
    final sustainableKbps = effectiveThroughput != null && effectiveThroughput > 0
        ? (effectiveThroughput * _config.bandwidthSafetyMargin).round()
        : null;

    final candidates = channel.alternatives
        .map(healthRegistry.applyVerifiedQuality)
        .where((alt) =>
            alt.streamId != current.streamId &&
            healthRegistry.isAvailable(alt.streamId, now: ts))
        .toList();

    if (candidates.isEmpty) return const [];

    // Prefer lower-bitrate alternatives first when failing over due to buffering
    final lowerCandidates = candidates
        .where((a) => a.tier.rank < current.tier.rank)
        .toList();

    List<StreamAlternative> primaryPool = candidates;
    if (sustainableKbps != null) {
      final sustainable = candidates
          .where((a) => a.estimatedBitrateKbps <= sustainableKbps)
          .toList();
      if (sustainable.isNotEmpty) {
        primaryPool = sustainable;
      } else if (lowerCandidates.isNotEmpty) {
        primaryPool = lowerCandidates;
      }
    } else if (!isExpired && lowerCandidates.isNotEmpty) {
      primaryPool = lowerCandidates;
    }

    int compareAlt(StreamAlternative a, StreamAlternative b) {
      final relA = healthRegistry.reliabilityScore(a.streamId);
      final relB = healthRegistry.reliabilityScore(b.streamId);
      if ((relB - relA).abs() > 0.25) {
        return relB.compareTo(relA);
      }
      return b.tier.rank.compareTo(a.tier.rank);
    }

    primaryPool.sort(compareAlt);

    // Append remaining healthy alternatives (e.g. same-tier backups from other
    // categories) after the primary lower-quality pool so we still have fallback
    // options if the lower-tier stream is offline.
    final primaryIds = primaryPool.map((a) => a.streamId).toSet();
    final secondaryPool = candidates
        .where((a) => !primaryIds.contains(a.streamId))
        .toList()
      ..sort(compareAlt);

    return [...primaryPool, ...secondaryPool];
  }

  /// Marks a candidate that failed background reachability probing so it enters
  /// cooldown and is not probed repeatedly.
  void markCandidateUnreachable(
    StreamAlternative candidate, {
    bool isExpired = false,
    DateTime? now,
  }) {
    final channel = _activeChannel;
    if (channel == null) return;
    healthRegistry.recordFailure(
      candidate.streamId,
      channel.logicalId,
      isExpired: isExpired,
      config: _config,
      now: now ?? DateTime.now(),
    );
  }

  /// Commits a failover transition ONLY after [chosen] has been verified
  /// reachable in the background.
  void commitVerifiedFailover(
    StreamAlternative chosen, {
    required String reason,
    bool isExpired = false,
    DateTime? now,
  }) {
    final channel = _activeChannel;
    final current = _activeStream;
    if (channel == null || current == null) return;

    final ts = now ?? DateTime.now();
    healthRegistry.recordFailure(
      current.streamId,
      channel.logicalId,
      isExpired: isExpired,
      config: _config,
      now: ts,
    );

    _failoverStartedAt = ts;
    _lastSwitchAt = ts;
    _recentRebuffers.clear();
    _stablePlaybackSince = null;

    _lastFailoverEvent = TissFailoverEvent(
      timestamp: ts,
      logicalChannelName: channel.displayName,
      fromQuality: current.displayQuality,
      toQuality: chosen.displayQuality,
      reason: reason,
      recoveryDurationMs: 0,
      wasUpgrade: false,
      succeeded: false,
    );

    _activeStream = chosen;
  }

  /// Selects the best sustainable alternative within the SAME [LogicalChannel]
  /// when the current stream fails or buffers repeatedly.
  ///
  /// Never switches to another logical channel or incompatible regional feed.
  /// Returns `null` when no alternative is available (all failed or single stream).
  StreamAlternative? selectFailoverAlternative({
    required String reason,
    int? throughputKbps,
    bool isExpired = false,
    bool allowFallbackInManualMode = false,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final ranked = rankedFailoverCandidates(
      throughputKbps: throughputKbps,
      isExpired: isExpired,
      allowFallbackInManualMode: allowFallbackInManualMode,
      now: ts,
    );
    if (ranked.isEmpty) return null;

    final chosen = ranked.first;
    commitVerifiedFailover(
      chosen,
      reason: reason,
      isExpired: isExpired,
      now: ts,
    );
    return chosen;
  }

  /// QualityRecoveryController: checks whether sustained healthy playback &
  /// improved bandwidth warrant a controlled upgrade toward preferred quality.
  StreamAlternative? evaluateQualityUpgrade({
    int? throughputKbps,
    required Duration bufferDuration,
    DateTime? now,
  }) {
    if (!_isAutoMode || !_config.autoUpgradeEnabled || _config.simulatePoorNetwork) {
      return null;
    }
    final channel = _activeChannel;
    final current = _activeStream;
    final preferred = _preferredStream ?? channel?.primaryStream;
    if (channel == null || current == null || preferred == null) return null;
    if (current.tier.rank >= preferred.tier.rank) return null;

    final ts = now ?? DateTime.now();

    // Enforce minimum stability duration & upgrade cooldown (hysteresis)
    if (_stablePlaybackSince == null ||
        ts.difference(_stablePlaybackSince!).inSeconds <
            _config.stabilityPeriodSeconds) {
      return null;
    }
    if (_lastSwitchAt != null &&
        ts.difference(_lastSwitchAt!).inSeconds <
            _config.upgradeCooldownSeconds) {
      return null;
    }
    if (bufferDuration.inSeconds < 4) return null;

    final sustainableKbps = throughputKbps != null && throughputKbps > 0
        ? (throughputKbps * _config.bandwidthSafetyMargin).round()
        : null;

    // Find candidate higher than current, up to preferred, that is healthy & sustainable
    final upgradeCandidates = channel.alternatives
        .map(healthRegistry.applyVerifiedQuality)
        .where((alt) =>
            alt.tier.rank > current.tier.rank &&
            alt.tier.rank <= preferred.tier.rank &&
            healthRegistry.isAvailable(alt.streamId, now: ts) &&
            (sustainableKbps == null ||
                alt.estimatedBitrateKbps <= sustainableKbps))
        .toList()
      ..sort((a, b) => a.tier.rank.compareTo(b.tier.rank)); // Step up gradually

    if (upgradeCandidates.isEmpty) return null;

    final target = upgradeCandidates.first;
    _failoverStartedAt = ts;
    _lastSwitchAt = ts;
    _stablePlaybackSince = null;

    _lastFailoverEvent = TissFailoverEvent(
      timestamp: ts,
      logicalChannelName: channel.displayName,
      fromQuality: current.displayQuality,
      toQuality: target.displayQuality,
      reason: 'connection_improved',
      recoveryDurationMs: 0,
      wasUpgrade: true,
      succeeded: false,
    );

    _activeStream = target;
    return target;
  }

  /// Returns a sanitized diagnostics snapshot (no raw URLs or credentials).
  TissDiagnosticsSnapshot diagnosticsSnapshot({DateTime? now}) {
    final channel = _activeChannel;
    final current = _activeStream;
    final ts = now ?? DateTime.now();

    final failedIds = channel == null
        ? const <String>[]
        : healthRegistry
            .failedRecordsForChannel(channel.logicalId, now: ts)
            .map((r) {
              for (final alt in channel.alternatives) {
                if (alt.streamId == r.streamId) {
                  return '${alt.displayQuality}${r.isExpired ? " (expired)" : ""}';
                }
              }
              return r.streamId;
            })
            .toList();

    return TissDiagnosticsSnapshot(
      logicalChannelName: channel?.displayName,
      activeStreamRedactedId: current != null
          ? StreamValidator.redactUrl(current.streamUrl)
          : null,
      activeQualityLabel: current?.qualityMenuLabel,
      isAutoMode: _isAutoMode,
      availableQualities: channel?.alternatives
              .map((a) => healthRegistry.applyVerifiedQuality(a).qualityMenuLabel)
              .toList() ??
          const [],
      failedQualities: failedIds,
      lastFailoverEvent: _lastFailoverEvent,
      successfulRecoveries: _successfulRecoveries,
      autoUpgradeEnabled: _config.autoUpgradeEnabled,
      simulatePoorNetwork: _config.simulatePoorNetwork,
    );
  }
}
