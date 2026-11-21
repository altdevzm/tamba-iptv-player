/// Granular playback states for the IPTV engine.
enum PlaybackState {
  idle,
  initializing,
  loading,
  buffering,
  playing,
  paused,
  seeking,
  reconnecting,
  completed,
  failed,
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
