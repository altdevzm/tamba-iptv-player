import 'streaming_models.dart';

/// Records sanitized playback telemetry for developer diagnostics and
/// performance baseline measurement. Never stores raw URLs or credentials.
class StreamingAnalytics {
  static const int _maxStartupSamples = 20;
  static const int _maxRecentEvents = 15;

  final List<int> _startupSamplesMs = [];
  final List<String> _recentEvents = [];

  DateTime? _playbackRequestAt;
  DateTime? _channelSwitchAt;
  DateTime? _bufferingStartedAt;

  int? _lastStartupMs;
  int? _lastChannelSwitchMs;
  int _rebufferCount = 0;
  int _totalBufferingMs = 0;
  int _droppedFrames = 0;
  int? _estimatedThroughputKbps;
  String _selectedQualityLabel = 'Fixed quality (ABR N/A)';
  bool _supportsAbr = false;
  int _recoveryAttempts = 0;
  int _recoverySuccesses = 0;
  StreamFailureKind _lastFailureKind = StreamFailureKind.none;

  void recordPlaybackStart({bool isChannelSwitch = false}) {
    final now = DateTime.now();
    _playbackRequestAt = now;
    if (isChannelSwitch) {
      _channelSwitchAt = now;
    } else {
      _channelSwitchAt = null;
    }
    _bufferingStartedAt = null;
    _rebufferCount = 0;
    _totalBufferingMs = 0;
    _droppedFrames = 0;
    _lastFailureKind = StreamFailureKind.none;
    _addEvent(isChannelSwitch ? 'Channel switch started' : 'Playback started');
  }

  void recordFirstFrame() {
    final now = DateTime.now();
    if (_playbackRequestAt != null) {
      final elapsed = now.difference(_playbackRequestAt!).inMilliseconds;
      _lastStartupMs = elapsed;
      _startupSamplesMs.add(elapsed);
      if (_startupSamplesMs.length > _maxStartupSamples) {
        _startupSamplesMs.removeAt(0);
      }
      _playbackRequestAt = null;
      _addEvent('First frame rendered in ${elapsed}ms');
    }
    if (_channelSwitchAt != null) {
      _lastChannelSwitchMs = now.difference(_channelSwitchAt!).inMilliseconds;
      _channelSwitchAt = null;
    }
  }

  void recordBufferingChanged(bool isBuffering, {required bool hasStarted}) {
    final now = DateTime.now();
    if (isBuffering) {
      if (_bufferingStartedAt == null) {
        _bufferingStartedAt = now;
        if (hasStarted) {
          _rebufferCount++;
          _addEvent('Rebuffer #$_rebufferCount');
        }
      }
    } else if (_bufferingStartedAt != null) {
      _totalBufferingMs += now.difference(_bufferingStartedAt!).inMilliseconds;
      _bufferingStartedAt = null;
    }
  }

  void recordRecoveryAttempt(int attempt, String reason) {
    _recoveryAttempts++;
    _addEvent('Recovery #$attempt ($reason)');
  }

  void recordRecoverySuccess() {
    _recoverySuccesses++;
    _addEvent('Recovery succeeded');
  }

  void recordFailure(StreamFailureKind kind) {
    _lastFailureKind = kind;
    _addEvent('Playback failed: ${kind.name}');
  }

  void updateQuality({
    required String label,
    required bool supportsAbr,
  }) {
    _selectedQualityLabel = label;
    _supportsAbr = supportsAbr;
  }

  void updateRuntimeMetrics({
    int? droppedFrames,
    int? throughputKbps,
  }) {
    if (droppedFrames != null) _droppedFrames = droppedFrames;
    if (throughputKbps != null && throughputKbps > 0) {
      _estimatedThroughputKbps = throughputKbps;
    }
  }

  StreamingAnalyticsSnapshot snapshot() {
    final avgStartup = _startupSamplesMs.isEmpty
        ? null
        : (_startupSamplesMs.reduce((a, b) => a + b) / _startupSamplesMs.length)
            .round();

    return StreamingAnalyticsSnapshot(
      lastStartupMs: _lastStartupMs,
      averageStartupMs: avgStartup,
      lastChannelSwitchMs: _lastChannelSwitchMs,
      rebufferCount: _rebufferCount,
      totalBufferingMs: _totalBufferingMs,
      droppedFrames: _droppedFrames,
      estimatedThroughputKbps: _estimatedThroughputKbps,
      selectedQualityLabel: _selectedQualityLabel,
      supportsAbr: _supportsAbr,
      recoveryAttempts: _recoveryAttempts,
      recoverySuccesses: _recoverySuccesses,
      lastFailureKind: _lastFailureKind,
      rootCauseHint: _computeRootCauseHint(),
      recentEvents: List.unmodifiable(_recentEvents),
    );
  }

  String _computeRootCauseHint() {
    switch (_lastFailureKind) {
      case StreamFailureKind.networkError:
        return 'Network: Check Wi-Fi/mobile signal or try Stable profile.';
      case StreamFailureKind.expiredOrUnauthorized:
        return 'Source Auth: Playlist token/account rejected (HTTP 401/403).';
      case StreamFailureKind.streamUnavailable:
        return 'Stream Source: Channel/VOD is offline on provider server.';
      case StreamFailureKind.unsupportedFormat:
        return 'Format: Unsupported container/codec — try switching engine.';
      case StreamFailureKind.decoderError:
        return 'Device Decoder: Switch engine (MPV ↔ LibVLC) in Settings.';
      case StreamFailureKind.invalidUrl:
        return 'Playlist: Malformed or empty stream URL.';
      case StreamFailureKind.none:
        if (_droppedFrames > 60) {
          return 'Device: High dropped frames — hardware decoder may be overloaded.';
        }
        if (_rebufferCount >= 3) {
          return 'Network/Source: Frequent rebuffering — switch to Stable profile.';
        }
        return 'Healthy playback pipeline.';
    }
  }

  void _addEvent(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _recentEvents.insert(0, '[$ts] $msg');
    if (_recentEvents.length > _maxRecentEvents) {
      _recentEvents.removeLast();
    }
  }
}
