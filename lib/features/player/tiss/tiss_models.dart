/// SmartStream playback modes that directly control quality selection,
/// bandwidth safety margins, failover thresholds, and automatic recovery.
enum SmartStreamMode {
  balanced,
  bestQuality,
  mostStable,
}

extension SmartStreamModeInfo on SmartStreamMode {
  String get label => switch (this) {
        SmartStreamMode.balanced => 'Balanced',
        SmartStreamMode.bestQuality => 'Best Quality',
        SmartStreamMode.mostStable => 'Most Stable',
      };

  String get description => switch (this) {
        SmartStreamMode.balanced =>
          'Selects best sustainable quality, fails over on buffering, and restores quality when stable.',
        SmartStreamMode.bestQuality =>
          'Prioritizes highest available resolution while still protecting against sustained buffering.',
        SmartStreamMode.mostStable =>
          'Prefers lower-bitrate streams with conservative margins and avoids unnecessary upgrades.',
      };

  double get bandwidthSafetyMargin => switch (this) {
        SmartStreamMode.balanced => 0.80,
        SmartStreamMode.bestQuality => 0.92,
        SmartStreamMode.mostStable => 0.65,
      };

  int get rebufferThreshold => switch (this) {
        SmartStreamMode.balanced => 2,
        SmartStreamMode.bestQuality => 3,
        SmartStreamMode.mostStable => 1,
      };

  bool get defaultAutoUpgrade => switch (this) {
        SmartStreamMode.balanced => true,
        SmartStreamMode.bestQuality => true,
        SmartStreamMode.mostStable => false,
      };
}

/// Distinguishes where a stream's quality metadata originated.
enum QualitySource {
  providerLabel,
  manifestDeclared,
  playbackReported,
}

extension QualitySourceLabel on QualitySource {
  String get label => switch (this) {
        QualitySource.providerLabel => 'Provider label',
        QualitySource.manifestDeclared => 'Manifest',
        QualitySource.playbackReported => 'Verified playback',
      };
}

/// Ordered quality tiers supported by Tamba SmartStream / TISS.
enum StreamQualityTier {
  uhd4k,
  qhd1440,
  fhd1080,
  hd720,
  sd576,
  sd480,
  low360,
  unknown,
}

extension StreamQualityTierInfo on StreamQualityTier {
  /// Higher rank means higher visual quality.
  int get rank => switch (this) {
        StreamQualityTier.uhd4k => 70,
        StreamQualityTier.qhd1440 => 60,
        StreamQualityTier.fhd1080 => 50,
        StreamQualityTier.hd720 => 40,
        StreamQualityTier.sd576 => 30,
        StreamQualityTier.sd480 => 20,
        StreamQualityTier.low360 => 10,
        StreamQualityTier.unknown => 25,
      };

  String get shortLabel => switch (this) {
        StreamQualityTier.uhd4k => '4K',
        StreamQualityTier.qhd1440 => '1440p',
        StreamQualityTier.fhd1080 => '1080p',
        StreamQualityTier.hd720 => '720p',
        StreamQualityTier.sd576 => '576p',
        StreamQualityTier.sd480 => '480p',
        StreamQualityTier.low360 => '360p',
        StreamQualityTier.unknown => 'SD',
      };

  /// Conservative estimated bitrate in kbps when actual stream bitrate is unknown.
  int get defaultEstimatedBitrateKbps => switch (this) {
        StreamQualityTier.uhd4k => 15000,
        StreamQualityTier.qhd1440 => 10000,
        StreamQualityTier.fhd1080 => 6500,
        StreamQualityTier.hd720 => 3500,
        StreamQualityTier.sd576 => 2000,
        StreamQualityTier.sd480 => 1200,
        StreamQualityTier.low360 => 600,
        StreamQualityTier.unknown => 2500,
      };

  static StreamQualityTier fromHeight(int height) {
    if (height >= 2000) return StreamQualityTier.uhd4k;
    if (height >= 1350) return StreamQualityTier.qhd1440;
    if (height >= 1000) return StreamQualityTier.fhd1080;
    if (height >= 680) return StreamQualityTier.hd720;
    if (height >= 540) return StreamQualityTier.sd576;
    if (height >= 440) return StreamQualityTier.sd480;
    if (height > 0) return StreamQualityTier.low360;
    return StreamQualityTier.unknown;
  }
}

/// A single stream URL alternative belonging to a [LogicalChannel].
class StreamAlternative {
  final String streamId;
  final String logicalChannelId;
  final int? contentDbId;
  final String providerId;
  final String originalTitle;
  final String streamUrl;
  final String displayQuality;
  final StreamQualityTier tier;
  final int? verifiedWidth;
  final int? verifiedHeight;
  final bool isQualityVerified;
  final QualitySource qualitySource;
  final int estimatedBitrateKbps;
  final String? codec;
  final String? regionTag;
  final String? epgChannelId;
  final String? logoUrl;
  final int preferredOrder;

  const StreamAlternative({
    required this.streamId,
    required this.logicalChannelId,
    this.contentDbId,
    required this.providerId,
    required this.originalTitle,
    required this.streamUrl,
    required this.displayQuality,
    required this.tier,
    this.verifiedWidth,
    this.verifiedHeight,
    this.isQualityVerified = false,
    this.qualitySource = QualitySource.providerLabel,
    required this.estimatedBitrateKbps,
    this.codec,
    this.regionTag,
    this.epgChannelId,
    this.logoUrl,
    this.preferredOrder = 0,
  });

  String get qualityMenuLabel {
    if (qualitySource == QualitySource.playbackReported &&
        verifiedHeight != null) {
      return '${verifiedHeight}p';
    }
    if (qualitySource == QualitySource.manifestDeclared) {
      return displayQuality;
    }
    return '$displayQuality (est.)';
  }

  StreamAlternative copyWith({
    int? verifiedWidth,
    int? verifiedHeight,
    bool? isQualityVerified,
    QualitySource? qualitySource,
    StreamQualityTier? tier,
    String? displayQuality,
    int? estimatedBitrateKbps,
    String? codec,
    int? preferredOrder,
  }) {
    return StreamAlternative(
      streamId: streamId,
      logicalChannelId: logicalChannelId,
      contentDbId: contentDbId,
      providerId: providerId,
      originalTitle: originalTitle,
      streamUrl: streamUrl,
      displayQuality: displayQuality ?? this.displayQuality,
      tier: tier ?? this.tier,
      verifiedWidth: verifiedWidth ?? this.verifiedWidth,
      verifiedHeight: verifiedHeight ?? this.verifiedHeight,
      isQualityVerified: isQualityVerified ?? this.isQualityVerified,
      qualitySource: qualitySource ?? this.qualitySource,
      estimatedBitrateKbps: estimatedBitrateKbps ?? this.estimatedBitrateKbps,
      codec: codec ?? this.codec,
      regionTag: regionTag,
      epgChannelId: epgChannelId,
      logoUrl: logoUrl,
      preferredOrder: preferredOrder ?? this.preferredOrder,
    );
  }
}

/// A single logical TV channel grouping one or more quality alternatives.
class LogicalChannel {
  final String logicalId;
  final String displayName;
  final String? logoUrl;
  final int? categoryId;
  final String? epgChannelId;
  final String? regionTag;
  final List<StreamAlternative> alternatives;
  final StreamQualityTier? preferredQuality;
  final double matchConfidence;

  const LogicalChannel({
    required this.logicalId,
    required this.displayName,
    this.logoUrl,
    this.categoryId,
    this.epgChannelId,
    this.regionTag,
    required this.alternatives,
    this.preferredQuality,
    this.matchConfidence = 1.0,
  });

  bool get hasMultipleQualities => alternatives.length > 1;

  /// Highest-quality alternative (default entry point).
  StreamAlternative get primaryStream => alternatives.first;

  /// Conservative fallback (highest tier <= 720p, or lowest available).
  StreamAlternative get defaultFallbackStream {
    for (final alt in alternatives) {
      if (alt.tier.rank <= StreamQualityTier.hd720.rank) return alt;
    }
    return alternatives.last;
  }

  /// Compact badge summary for channel cards (e.g. "4K • 1080p • 720p").
  String get qualitySummary {
    final labels = <String>[];
    for (final alt in alternatives) {
      if (!labels.contains(alt.displayQuality)) {
        labels.add(alt.displayQuality);
      }
      if (labels.length == 3) break;
    }
    return labels.join(' • ');
  }
}

/// Health & failure history record for an individual [StreamAlternative].
class StreamHealthRecord {
  final String streamId;
  final String logicalChannelId;
  final DateTime? lastSuccessfulPlayback;
  final DateTime? lastFailureAt;
  final int? lastStartupMs;
  final int bufferingEvents;
  final int errorCount;
  final int consecutiveFailures;
  final int recoverySuccesses;
  final bool isExpired;
  final DateTime? cooldownUntil;

  const StreamHealthRecord({
    required this.streamId,
    required this.logicalChannelId,
    this.lastSuccessfulPlayback,
    this.lastFailureAt,
    this.lastStartupMs,
    this.bufferingEvents = 0,
    this.errorCount = 0,
    this.consecutiveFailures = 0,
    this.recoverySuccesses = 0,
    this.isExpired = false,
    this.cooldownUntil,
  });

  bool isTemporarilyExcluded(DateTime now) =>
      cooldownUntil != null && now.isBefore(cooldownUntil!);

  /// Reliability score in `[0.0, 1.0]` used to rank alternatives.
  double get reliabilityScore {
    if (isExpired) return 0.05;
    final penalty = (consecutiveFailures * 0.25) +
        (errorCount * 0.08) +
        (bufferingEvents * 0.04);
    final bonus = lastSuccessfulPlayback != null ? 0.15 : 0.0;
    return (1.0 - penalty + bonus).clamp(0.05, 1.0);
  }

  StreamHealthRecord copyWith({
    DateTime? lastSuccessfulPlayback,
    DateTime? lastFailureAt,
    int? lastStartupMs,
    int? bufferingEvents,
    int? errorCount,
    int? consecutiveFailures,
    int? recoverySuccesses,
    bool? isExpired,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) {
    return StreamHealthRecord(
      streamId: streamId,
      logicalChannelId: logicalChannelId,
      lastSuccessfulPlayback:
          lastSuccessfulPlayback ?? this.lastSuccessfulPlayback,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
      lastStartupMs: lastStartupMs ?? this.lastStartupMs,
      bufferingEvents: bufferingEvents ?? this.bufferingEvents,
      errorCount: errorCount ?? this.errorCount,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      recoverySuccesses: recoverySuccesses ?? this.recoverySuccesses,
      isExpired: isExpired ?? this.isExpired,
      cooldownUntil:
          clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
    );
  }
}

/// Recorded failover or automatic quality upgrade event.
class TissFailoverEvent {
  final DateTime timestamp;
  final String logicalChannelName;
  final String fromQuality;
  final String toQuality;
  final String reason;
  final int recoveryDurationMs;
  final bool wasUpgrade;
  final bool succeeded;

  const TissFailoverEvent({
    required this.timestamp,
    required this.logicalChannelName,
    required this.fromQuality,
    required this.toQuality,
    required this.reason,
    required this.recoveryDurationMs,
    this.wasUpgrade = false,
    this.succeeded = true,
  });

  String get summary =>
      '${wasUpgrade ? "Upgrade" : "Failover"} $fromQuality → $toQuality ($reason, ${recoveryDurationMs}ms)';
}

/// Configurable thresholds for SmartStream / TISS failover & quality recovery.
class TissConfig {
  final SmartStreamMode mode;
  final int rebufferThreshold;
  final int detectionWindowSeconds;
  final int stabilityPeriodSeconds;
  final int upgradeCooldownSeconds;
  final double bandwidthSafetyMargin;
  final int failureCooldownSeconds;
  final int expiredCooldownSeconds;
  final bool autoUpgradeEnabled;
  final bool allowEmergencyFallbackInManualMode;
  final bool simulatePoorNetwork;

  const TissConfig({
    this.mode = SmartStreamMode.balanced,
    this.rebufferThreshold = 2,
    this.detectionWindowSeconds = 20,
    this.stabilityPeriodSeconds = 45,
    this.upgradeCooldownSeconds = 60,
    this.bandwidthSafetyMargin = 0.80,
    this.failureCooldownSeconds = 90,
    this.expiredCooldownSeconds = 600,
    this.autoUpgradeEnabled = true,
    this.allowEmergencyFallbackInManualMode = true,
    this.simulatePoorNetwork = false,
  });

  factory TissConfig.forMode(
    SmartStreamMode mode, {
    bool? autoUpgradeEnabled,
    bool allowEmergencyFallbackInManualMode = true,
  }) {
    return TissConfig(
      mode: mode,
      rebufferThreshold: mode.rebufferThreshold,
      bandwidthSafetyMargin: mode.bandwidthSafetyMargin,
      autoUpgradeEnabled: autoUpgradeEnabled ?? mode.defaultAutoUpgrade,
      allowEmergencyFallbackInManualMode: allowEmergencyFallbackInManualMode,
    );
  }

  TissConfig copyWith({
    SmartStreamMode? mode,
    int? rebufferThreshold,
    int? detectionWindowSeconds,
    int? stabilityPeriodSeconds,
    int? upgradeCooldownSeconds,
    double? bandwidthSafetyMargin,
    int? failureCooldownSeconds,
    int? expiredCooldownSeconds,
    bool? autoUpgradeEnabled,
    bool? allowEmergencyFallbackInManualMode,
    bool? simulatePoorNetwork,
  }) {
    return TissConfig(
      mode: mode ?? this.mode,
      rebufferThreshold: rebufferThreshold ?? this.rebufferThreshold,
      detectionWindowSeconds:
          detectionWindowSeconds ?? this.detectionWindowSeconds,
      stabilityPeriodSeconds:
          stabilityPeriodSeconds ?? this.stabilityPeriodSeconds,
      upgradeCooldownSeconds:
          upgradeCooldownSeconds ?? this.upgradeCooldownSeconds,
      bandwidthSafetyMargin:
          bandwidthSafetyMargin ?? this.bandwidthSafetyMargin,
      failureCooldownSeconds:
          failureCooldownSeconds ?? this.failureCooldownSeconds,
      expiredCooldownSeconds:
          expiredCooldownSeconds ?? this.expiredCooldownSeconds,
      autoUpgradeEnabled: autoUpgradeEnabled ?? this.autoUpgradeEnabled,
      allowEmergencyFallbackInManualMode: allowEmergencyFallbackInManualMode ??
          this.allowEmergencyFallbackInManualMode,
      simulatePoorNetwork: simulatePoorNetwork ?? this.simulatePoorNetwork,
    );
  }
}

/// Sanitized diagnostics snapshot for the TISS Developer Diagnostics panel.
class TissDiagnosticsSnapshot {
  final String? logicalChannelName;
  final String? activeStreamRedactedId;
  final String? activeQualityLabel;
  final bool isAutoMode;
  final List<String> availableQualities;
  final List<String> failedQualities;
  final TissFailoverEvent? lastFailoverEvent;
  final int successfulRecoveries;
  final bool autoUpgradeEnabled;
  final bool simulatePoorNetwork;

  const TissDiagnosticsSnapshot({
    this.logicalChannelName,
    this.activeStreamRedactedId,
    this.activeQualityLabel,
    this.isAutoMode = true,
    this.availableQualities = const [],
    this.failedQualities = const [],
    this.lastFailoverEvent,
    this.successfulRecoveries = 0,
    this.autoUpgradeEnabled = true,
    this.simulatePoorNetwork = false,
  });
}
