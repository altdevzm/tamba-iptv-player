/// Granular playback states for the IPTV engine.
enum PlaybackState {
  idle,
  initializing,
  connecting,
  loading,
  buffering,
  playing,
  paused,
  seeking,
  reconnecting,
  completed,
  streamUnavailable,
  unsupportedFormat,
  failed,
}

extension PlaybackStateLabel on PlaybackState {
  bool get isError =>
      this == PlaybackState.failed ||
      this == PlaybackState.streamUnavailable ||
      this == PlaybackState.unsupportedFormat;

  String get displayLabel => switch (this) {
        PlaybackState.idle => 'Idle',
        PlaybackState.initializing => 'Initializing',
        PlaybackState.connecting => 'Connecting...',
        PlaybackState.loading => 'Loading stream...',
        PlaybackState.buffering => 'Buffering...',
        PlaybackState.playing => 'Playing',
        PlaybackState.paused => 'Paused',
        PlaybackState.seeking => 'Seeking...',
        PlaybackState.reconnecting => 'Reconnecting...',
        PlaybackState.completed => 'Completed',
        PlaybackState.streamUnavailable => 'Stream unavailable',
        PlaybackState.unsupportedFormat => 'Unsupported format',
        PlaybackState.failed => 'Playback error',
      };
}

/// Playback profiles controlling decoder and buffer settings.
enum PlaybackProfile {
  auto,
  dataSaver,
  moreStable,
  highQuality,
}

enum LiveStreamFormat {
  providerDefault,
  ts,
  hls,
}

/// Selectable internal playback backend.
enum PlaybackEngine {
  mediaKit,
  libVlc,
}

extension PlaybackEngineLabel on PlaybackEngine {
  String get label => switch (this) {
        PlaybackEngine.mediaKit => 'media_kit (libmpv)',
        PlaybackEngine.libVlc => 'LibVLC (Bundled)',
      };

  String get shortLabel => switch (this) {
        PlaybackEngine.mediaKit => 'MPV',
        PlaybackEngine.libVlc => 'VLC',
      };
}
