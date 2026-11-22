import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'stream_validator.dart';
import 'streaming_analytics.dart';
import 'streaming_models.dart';

/// Central StreamingManager encapsulating buffer tuning, ABR quality selection,
/// stream validation, sanitized analytics, backoff scheduling, and bounded
/// image/resource caches — cleanly separated from Flutter UI widgets.
class StreamingManager {
  final StreamValidator validator;
  final StreamingAnalytics analytics;

  BufferProfile _profile = BufferProfile.balanced;
  List<StreamRendition> _availableRenditions = const [];
  StreamRendition _selectedRendition = StreamRendition.auto;
  bool _manualQualityOverride = false;
  DateTime? _lastQualitySwitchAt;

  static const Duration _abrSwitchCooldown = Duration(seconds: 15);
  static const List<int> backoffDelaysSeconds = [1, 2, 4, 8, 15];
  static const int maxRecoveryAttempts = 5;

  StreamingManager({Dio? dio})
      : validator = StreamValidator(dio),
        analytics = StreamingAnalytics();

  BufferProfile get profile => _profile;
  List<StreamRendition> get availableRenditions => _availableRenditions;
  StreamRendition get selectedRendition => _selectedRendition;
  bool get supportsAbr => _availableRenditions.length > 1;
  bool get isManualQuality => _manualQualityOverride;

  /// Bounds Flutter's decoded image cache to prevent memory leaks / OOM on
  /// low-end Android phones and Android TV boxes when scrolling large poster
  /// and channel logo walls.
  static void configureResourceCaches() {
    final isMobileOrTv = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = isMobileOrTv ? 180 : 350;
    cache.maximumSizeBytes =
        (isMobileOrTv ? 75 : 150) * 1024 * 1024; // 75 MiB mobile/TV, 150 MiB desktop
  }

  /// Resolves the active [BufferConfig] for the current platform and stream type.
  BufferConfig resolveBufferConfig({required bool isLive}) {
    final isLowMemoryDevice = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return BufferConfig.resolve(
      profile: _profile,
      isLive: isLive,
      isLowMemoryDevice: isLowMemoryDevice,
    );
  }

  void setBufferProfile(BufferProfile newProfile) {
    _profile = newProfile;
  }

  /// Returns the mpv property map to apply for fast startup, socket-level
  /// FFmpeg reconnects, bounded memory, and optional HLS bitrate cap.
  Map<String, String> buildMpvProperties({
    required bool isLive,
    required bool isAndroid,
  }) {
    final cfg = resolveBufferConfig(isLive: isLive);
    final props = <String, String>{
      if (!isAndroid) 'hwdec': 'auto-safe',
      'cache': 'yes',
      'cache-secs': cfg.cacheSecs.toString(),
      'demuxer-readahead-secs': cfg.readaheadSecs.toString(),
      'demuxer-max-bytes': cfg.demuxerMaxBytes.toString(),
      'demuxer-max-back-bytes': cfg.demuxerMaxBackBytes.toString(),
      'cache-pause-wait': cfg.cachePauseWaitSecs.toStringAsFixed(1),
      'network-timeout': cfg.networkTimeoutSecs.toString(),
      // Enable FFmpeg socket-level auto-reconnect so brief Wi-Fi drops recover
      // seamlessly without tearing down the player.
      'demuxer-lavf-o':
          'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1',
    };

    if (!_selectedRendition.isAuto && _selectedRendition.bandwidthBps > 0) {
      props['hls-bitrate'] = _selectedRendition.bandwidthBps.toString();
    } else if (_profile == BufferProfile.lowLatency) {
      props['hls-bitrate'] = 'max';
    } else {
      props['hls-bitrate'] = 'max';
    }

    return props;
  }

  /// Validates [url] and updates available ABR renditions.
  Future<StreamValidationResult> prepareStream(
    String url, {
    Map<String, String> headers = const {},
    bool isChannelSwitch = false,
  }) async {
    analytics.recordPlaybackStart(isChannelSwitch: isChannelSwitch);
    _availableRenditions = const [];
    _selectedRendition = StreamRendition.auto;
    _manualQualityOverride = false;

    final validation = await validator.validate(url, headers: headers);
    if (!validation.isValid) {
      analytics.recordFailure(validation.failureKind);
      return validation;
    }

    if (validation.supportsAbr && validation.renditions.length > 1) {
      _availableRenditions = [StreamRendition.auto, ...validation.renditions];
      analytics.updateQuality(
        label: 'Auto (${validation.renditions.length} qualities)',
        supportsAbr: true,
      );
    } else {
      _availableRenditions = const [];
      analytics.updateQuality(
        label: 'Fixed quality (ABR N/A)',
        supportsAbr: false,
      );
    }
    return validation;
  }

  /// Manually selects a rendition (or returns to `StreamRendition.auto`).
  /// Returns the variant URL to open if a specific HLS variant URI is available.
  String? selectManualQuality(StreamRendition rendition) {
    if (!supportsAbr) return null;
    _selectedRendition = rendition;
    _manualQualityOverride = !rendition.isAuto;
    _lastQualitySwitchAt = DateTime.now();
    analytics.updateQuality(
      label: rendition.isAuto
          ? 'Auto (${_availableRenditions.length - 1} qualities)'
          : rendition.label,
      supportsAbr: true,
    );
    return rendition.uri;
  }

  /// Evaluates observed bandwidth (`throughputKbps`) and rebuffer events to
  /// recommend an ABR rendition step-down or gradual step-up with hysteresis.
  /// Returns a new [StreamRendition] only when a switch is warranted.
  StreamRendition? evaluateAdaptiveQuality({
    required int throughputKbps,
    required bool isRebuffering,
  }) {
    if (!supportsAbr || _manualQualityOverride) return null;
    final now = DateTime.now();
    if (_lastQualitySwitchAt != null &&
        now.difference(_lastQualitySwitchAt!) < _abrSwitchCooldown) {
      return null;
    }

    final variants = _availableRenditions.where((r) => !r.isAuto).toList();
    if (variants.length < 2) return null;

    // Sustainable bandwidth headroom (80% safety margin)
    final sustainableBps = (throughputKbps * 1000 * 0.80).round();

    StreamRendition? chosen;
    if (isRebuffering) {
      // Step down one tier below current or pick lowest variant under bandwidth
      final currentIdx = variants.indexWhere((v) => v.id == _selectedRendition.id);
      if (currentIdx >= 0 && currentIdx + 1 < variants.length) {
        chosen = variants[currentIdx + 1];
      } else {
        chosen = variants.last;
      }
    } else if (sustainableBps > 0) {
      // Pick highest rendition strictly below sustainable bandwidth
      for (final v in variants) {
        if (v.bandwidthBps > 0 && v.bandwidthBps <= sustainableBps) {
          chosen = v;
          break;
        }
      }
      chosen ??= variants.last;
    }

    if (chosen == null || chosen.id == _selectedRendition.id) return null;
    _selectedRendition = chosen;
    _lastQualitySwitchAt = now;
    analytics.updateQuality(
      label: 'Auto (${chosen.label})',
      supportsAbr: true,
    );
    return chosen;
  }

  /// Returns exponential backoff delay in seconds for [attemptIndex] (0-based).
  int backoffDelayForAttempt(int attemptIndex) {
    final clamped = attemptIndex.clamp(0, backoffDelaysSeconds.length - 1);
    return backoffDelaysSeconds[clamped];
  }
}
