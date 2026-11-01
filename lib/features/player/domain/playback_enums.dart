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
