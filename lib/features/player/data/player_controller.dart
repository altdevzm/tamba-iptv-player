import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:drift/drift.dart' as drift;

import '../../../shared/models/media_item.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../stalker/data/stalker_client.dart';
import '../domain/playback_enums.dart';
import '../streaming/stream_validator.dart';
import '../streaming/streaming_manager.dart';
import '../streaming/streaming_models.dart';
import '../tiss/channel_grouping_engine.dart';
import '../tiss/tiss_controller.dart';
import '../tiss/tiss_models.dart';
import 'libvlc_bridge.dart';

// ─── Rich Player State ────────────────────────────────────────────────────────

class PlayerState {
  final MediaItem? currentItem;
  final PlaybackState playbackState;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final Duration bufferDuration;
  final double volume;
  final bool isMuted;
  final bool isMiniPlayerVisible;
  final bool isFullscreen;
  final String? errorMessage;
  final int reconnectAttempt;
  final String? activeDecoder;
  final bool isHardwareAccelerated;
  final int? currentBitrate;
  final int droppedFrames;
  final PlaybackProfile playbackProfile;
  final LiveStreamFormat liveStreamFormat;
  final PlaybackEngine playbackEngine;
  final double playbackRate;
  final MediaItem? nextEpisodeItem;
  final bool autoPlayEnabled;
  final List<LibVlcTrack> vlcAudioTracks;
  final List<LibVlcTrack> vlcSubtitleTracks;
  final int activeVlcAudioTrack;
  final int activeVlcSubtitleTrack;
  final String? tissNotification;

  const PlayerState({
    this.currentItem,
    this.playbackState = PlaybackState.idle,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferDuration = Duration.zero,
    this.volume = 100.0,
    this.isMuted = false,
    this.isMiniPlayerVisible = false,
    this.isFullscreen = false,
    this.errorMessage,
    this.reconnectAttempt = 0,
    this.activeDecoder,
    this.isHardwareAccelerated = false,
    this.currentBitrate,
    this.droppedFrames = 0,
    this.playbackProfile = PlaybackProfile.auto,
    this.liveStreamFormat = LiveStreamFormat.providerDefault,
    this.playbackEngine = PlaybackEngine.mediaKit,
    this.playbackRate = 1.0,
    this.nextEpisodeItem,
    this.autoPlayEnabled = true,
    this.vlcAudioTracks = const [],
    this.vlcSubtitleTracks = const [],
    this.activeVlcAudioTrack = -1,
    this.activeVlcSubtitleTrack = -1,
    this.tissNotification,
  });

  PlayerState copyWith({
    MediaItem? currentItem,
    PlaybackState? playbackState,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    Duration? bufferDuration,
    double? volume,
    bool? isMuted,
    bool? isMiniPlayerVisible,
    bool? isFullscreen,
    String? errorMessage,
    bool clearError = false,
    int? reconnectAttempt,
    String? activeDecoder,
    bool? isHardwareAccelerated,
    int? currentBitrate,
    int? droppedFrames,
    PlaybackProfile? playbackProfile,
    LiveStreamFormat? liveStreamFormat,
    PlaybackEngine? playbackEngine,
    double? playbackRate,
    MediaItem? nextEpisodeItem,
    bool clearNextEpisode = false,
    bool? autoPlayEnabled,
    List<LibVlcTrack>? vlcAudioTracks,
    List<LibVlcTrack>? vlcSubtitleTracks,
    int? activeVlcAudioTrack,
    int? activeVlcSubtitleTrack,
    String? tissNotification,
    bool clearTissNotification = false,
  }) {
    return PlayerState(
      currentItem: currentItem ?? this.currentItem,
      playbackState: playbackState ?? this.playbackState,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferDuration: bufferDuration ?? this.bufferDuration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isMiniPlayerVisible: isMiniPlayerVisible ?? this.isMiniPlayerVisible,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      activeDecoder: activeDecoder ?? this.activeDecoder,
      isHardwareAccelerated:
          isHardwareAccelerated ?? this.isHardwareAccelerated,
      currentBitrate: currentBitrate ?? this.currentBitrate,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      playbackProfile: playbackProfile ?? this.playbackProfile,
      liveStreamFormat: liveStreamFormat ?? this.liveStreamFormat,
      playbackEngine: playbackEngine ?? this.playbackEngine,
      playbackRate: playbackRate ?? this.playbackRate,
      nextEpisodeItem:
          clearNextEpisode ? null : (nextEpisodeItem ?? this.nextEpisodeItem),
      autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
      vlcAudioTracks: vlcAudioTracks ?? this.vlcAudioTracks,
      vlcSubtitleTracks: vlcSubtitleTracks ?? this.vlcSubtitleTracks,
      activeVlcAudioTrack: activeVlcAudioTrack ?? this.activeVlcAudioTrack,
      activeVlcSubtitleTrack:
          activeVlcSubtitleTrack ?? this.activeVlcSubtitleTrack,
      tissNotification: clearTissNotification
          ? null
          : (tissNotification ?? this.tissNotification),
    );
  }
}

// ─── PlayerController ─────────────────────────────────────────────────────────

class PlayerController extends StateNotifier<PlayerState>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool _playerInitialized = false;

  /// Lazily initializes native libmpv + VideoController ONLY when playback
  /// actually starts, preventing 64MB+ native heap & EGL surface allocations
  /// from crashing low-RAM Smart TVs during cold startup before data loads.
  Player get player {
    _ensurePlayerInitialized();
    return _player!;
  }

  VideoController get videoController {
    _ensurePlayerInitialized();
    return _videoController!;
  }

  bool get isPlayerInitialized => _playerInitialized;

  void _ensurePlayerInitialized() {
    if (_playerInitialized && _player != null && _videoController != null) {
      return;
    }
    final isLowMemoryAndroid = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final p = Player(
      configuration: PlayerConfiguration(
        // 16 MB on Android/TV (down from 64 MB) to prevent native OOM on 1-2GB TVs
        bufferSize: isLowMemoryAndroid ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      ),
    );
    final vc = VideoController(
      p,
      configuration: const VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters: true,
      ),
    );
    _player = p;
    _videoController = vc;
    _playerInitialized = true;
    _initListeners();
  }

  final LibVlcBridge libVlcBridge = LibVlcBridge();
  final List<StreamSubscription> _subscriptions = [];
  final AppDatabase _db;
  final SecureStorageService _storage;
  final StalkerClient? _stalkerClient;
  final StreamingManager streamingManager;
  final TissController tissController = TissController();
  final Map<String, StalkerCredentials> _stalkerCredsCache = {};

  // Cached HTTP headers, live channel list & TISS logical channel lookup
  Map<String, String>? _cachedHeaders;
  String? _cachedLivePlaylistId;
  List<ContentItemsTableData> _cachedLiveChannels = const [];
  Map<String, LogicalChannel> _logicalByProviderId = const {};
  Timer? _tissNotificationTimer;

  bool get _usingLibVlc =>
      state.playbackEngine == PlaybackEngine.libVlc && LibVlcBridge.isSupported;

  Timer? _positionSaveTimer;
  Timer? _reconnectTimer;
  Timer? _stallDetectionTimer;
  late final Future<void> _preferencesLoaded;
  int _reconnectAttempt = 0;
  int _playbackEpoch = 0;
  bool _isRecovering = false;
  bool _isSearchingAlternative = false;
  bool _hasRenderedFirstFrame = false;
  DateTime? _bufferingSince;
  static const int _maxReconnectAttempts = StreamingManager.maxRecoveryAttempts;
  Duration? _lastObservedPosition;
  int _stalledSeconds = 0;

  // Prevent race conditions when switching streams rapidly
  String? _currentOpenUrl;
  MediaItem? _previousLiveChannel;

  PlayerController(this._db, this._storage, {Dio? dio})
      : _stalkerClient = dio != null ? StalkerClient(dio) : null,
        streamingManager = StreamingManager(dio: dio),
        super(const PlayerState()) {
    WidgetsBinding.instance.addObserver(this);
    _startPositionSaveTimer();
    _startStallDetection();
    _preferencesLoaded = _loadPreferences();
  }

  // ─── Initialization ──────────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    try {
      final values = await Future.wait([
        _storage.getPlaylistCredentials('filimu_autoplay_next'),
        _storage.getPlaylistCredentials('filimu_live_stream_format'),
        _storage.getPlaylistCredentials('filimu_playback_profile'),
        _storage.getPlaylistCredentials('filimu_playback_engine'),
        _storage.getPlaylistCredentials('filimu_smartstream_mode'),
        _storage.getPlaylistCredentials('filimu_smartstream_auto_switch'),
        _storage.getPlaylistCredentials('filimu_smartstream_auto_upgrade'),
      ]);
      final savedSmartMode = SmartStreamMode.values.firstWhere(
        (m) => m.name == values[4],
        orElse: () => SmartStreamMode.balanced,
      );
      tissController.setMode(savedSmartMode);
      tissController.updateConfig(
        tissController.config.copyWith(
          automaticSwitchingEnabled: values[5] != 'false',
          autoUpgradeEnabled:
              values[6] == null ? savedSmartMode.defaultAutoUpgrade : values[6] != 'false',
        ),
      );
      final formatValue = values[1];
      final format = LiveStreamFormat.values.firstWhere(
        (value) => value.name == formatValue,
        orElse: () => LiveStreamFormat.providerDefault,
      );
      final profile = PlaybackProfile.values.firstWhere(
        (value) => value.name == values[2],
        orElse: () => PlaybackProfile.auto,
      );
      final savedEngine = PlaybackEngine.values.firstWhere(
        (value) => value.name == values[3],
        orElse: () => PlaybackEngine.mediaKit,
      );
      final effectiveEngine =
          (savedEngine == PlaybackEngine.libVlc && LibVlcBridge.isSupported)
              ? PlaybackEngine.libVlc
              : PlaybackEngine.mediaKit;
      state = state.copyWith(
        autoPlayEnabled:
            values[0] == null ? state.autoPlayEnabled : values[0] != 'false',
        liveStreamFormat: format,
        playbackProfile: profile,
        playbackEngine: effectiveEngine,
      );
    } catch (_) {}
  }

  void _initListeners() {
    if (LibVlcBridge.isSupported) {
      _subscriptions.add(libVlcBridge.events.listen(_handleLibVlcEvent));
    }

    _subscriptions.add(player.stream.playing.listen((playing) {
      if (_usingLibVlc) return;
      if (!playing && state.isPlaying) {
        unawaited(_saveCurrentPosition());
      }
      if (state.currentItem == null) {
        state = state.copyWith(isPlaying: false);
        return;
      }
      if (playing) {
        if (!_hasRenderedFirstFrame) {
          _hasRenderedFirstFrame = true;
          streamingManager.analytics.recordFirstFrame();
        }
        final wasTissFailover = tissController.lastFailoverEvent != null &&
            !tissController.lastFailoverEvent!.succeeded;
        tissController.confirmPlayback(
          startupMs: streamingManager.analytics.snapshot().lastStartupMs,
          width: player.state.width,
          height: player.state.height,
        );
        if (wasTissFailover) {
          _showTissNotification('Playback restored.');
        }
        if (_isRecovering || _reconnectAttempt > 0) {
          _isRecovering = false;
          _reconnectAttempt = 0;
          streamingManager.analytics.recordRecoverySuccess();
        }
        _bufferingSince = null;
      }
      state = state.copyWith(
        isPlaying: playing,
        playbackState: playing ? PlaybackState.playing : PlaybackState.paused,
      );
    }));

    _subscriptions.add(player.stream.buffering.listen((buffering) {
      if (_usingLibVlc) return;
      streamingManager.analytics.recordBufferingChanged(
        buffering,
        hasStarted: _hasRenderedFirstFrame,
      );
      if (buffering) {
        _bufferingSince ??= DateTime.now();
        if (_hasRenderedFirstFrame &&
            tissController.recordRebufferAndShouldFailover()) {
          unawaited(_triggerTissFailover(reason: 'sustained_buffering'));
          return;
        }
        state = state.copyWith(
          isBuffering: true,
          playbackState: PlaybackState.buffering,
        );
      } else {
        _bufferingSince = null;
        if (state.playbackState == PlaybackState.buffering) {
          state = state.copyWith(
            isBuffering: false,
            playbackState:
                state.isPlaying ? PlaybackState.playing : PlaybackState.paused,
          );
        } else {
          state = state.copyWith(isBuffering: false);
        }
      }
    }));

    _subscriptions.add(player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
      // Detect near-completion for VOD (>= 95% watched)
      final dur = state.duration;
      if (dur.inSeconds > 30 &&
          pos.inSeconds >= (dur.inSeconds * 0.95).toInt() &&
          state.playbackState == PlaybackState.playing &&
          state.nextEpisodeItem == null &&
          state.currentItem?.type == MediaType.series) {
        _resolveNextEpisode();
      }
    }));

    _subscriptions.add(player.stream.duration.listen((dur) {
      state = state.copyWith(duration: dur);
    }));

    _subscriptions.add(player.stream.buffer.listen((buf) {
      state = state.copyWith(bufferDuration: buf);
    }));

    _subscriptions.add(player.stream.volume.listen((vol) {
      state = state.copyWith(volume: vol, isMuted: vol == 0);
    }));

    _subscriptions.add(player.stream.completed.listen((completed) {
      if (completed) {
        state = state.copyWith(playbackState: PlaybackState.completed);
        _saveCurrentPosition(); // Save final position
        _markWatchedIfComplete();
        // For live streams, attempt reconnect on completion (stream ended)
        if (state.currentItem?.type == MediaType.live) {
          _scheduleReconnect();
        }
      }
    }));

    _subscriptions.add(player.stream.error.listen((err) {
      if (err.isEmpty) return;
      final failureKind = StreamValidator.classifyPlayerError(err);
      streamingManager.analytics.recordFailure(failureKind);
      // Never log raw URLs or credentials
      debugPrint('[Tamba Player] Error (${failureKind.name}): ${_friendlyError(err)}');

      final item = state.currentItem;
      if (item?.type == MediaType.live &&
          tissController.hasAlternatives &&
          !_isRecovering) {
        final isExpired =
            failureKind == StreamFailureKind.expiredOrUnauthorized;
        unawaited(_triggerTissFailover(
          reason: failureKind.name,
          isExpired: isExpired,
          interruptCurrentOnFailure: true,
        ));
        return;
      }

      final isRecoverable = failureKind == StreamFailureKind.networkError ||
          (item?.type == MediaType.live &&
              failureKind == StreamFailureKind.streamUnavailable);

      if (isRecoverable &&
          !_isRecovering &&
          _reconnectAttempt < _maxReconnectAttempts) {
        _scheduleReconnect(reason: failureKind.name);
      } else if (!_isRecovering) {
        final targetState = switch (failureKind) {
          StreamFailureKind.unsupportedFormat =>
            PlaybackState.unsupportedFormat,
          StreamFailureKind.streamUnavailable ||
          StreamFailureKind.expiredOrUnauthorized =>
            PlaybackState.streamUnavailable,
          _ => PlaybackState.failed,
        };
        state = state.copyWith(
          isBuffering: false,
          playbackState: targetState,
          errorMessage: _friendlyError(err),
        );
      }
    }));
  }

  void _handleLibVlcEvent(Map<String, dynamic> event) {
    if (!_usingLibVlc) return;
    final type = event['type']?.toString();
    switch (type) {
      case 'playing':
        final playing = event['playing'] == true;
        if (!playing && state.isPlaying) {
          unawaited(_saveCurrentPosition());
        }
        if (state.currentItem == null) {
          state = state.copyWith(isPlaying: false);
          return;
        }
        state = state.copyWith(
          isPlaying: playing,
          playbackState: playing ? PlaybackState.playing : PlaybackState.paused,
        );
        break;
      case 'buffering':
        final buffering = event['buffering'] == true;
        state = state.copyWith(
          isBuffering: buffering,
          playbackState: buffering
              ? PlaybackState.buffering
              : (state.isPlaying ? PlaybackState.playing : state.playbackState),
        );
        break;
      case 'position':
        final posMs = (event['positionMs'] as num?)?.toInt() ?? 0;
        final durMs = (event['durationMs'] as num?)?.toInt() ?? 0;
        final pos = Duration(milliseconds: posMs);
        final dur = durMs > 0 ? Duration(milliseconds: durMs) : state.duration;
        state = state.copyWith(position: pos, duration: dur);
        if (dur.inSeconds > 30 &&
            pos.inSeconds >= (dur.inSeconds * 0.95).toInt() &&
            state.playbackState == PlaybackState.playing &&
            state.nextEpisodeItem == null &&
            state.currentItem?.type == MediaType.series) {
          _resolveNextEpisode();
        }
        break;
      case 'duration':
        final durMs = (event['durationMs'] as num?)?.toInt() ?? 0;
        if (durMs > 0) {
          state = state.copyWith(duration: Duration(milliseconds: durMs));
        }
        break;
      case 'tracks':
        final audioRaw = event['audioTracks'];
        final subRaw = event['subtitleTracks'];
        final audioTracks = audioRaw is List
            ? audioRaw.whereType<Map>().map(LibVlcTrack.fromMap).toList()
            : state.vlcAudioTracks;
        final subTracks = subRaw is List
            ? subRaw.whereType<Map>().map(LibVlcTrack.fromMap).toList()
            : state.vlcSubtitleTracks;
        state = state.copyWith(
          vlcAudioTracks: audioTracks,
          vlcSubtitleTracks: subTracks,
          activeVlcAudioTrack:
              (event['activeAudioTrack'] as num?)?.toInt() ??
                  state.activeVlcAudioTrack,
          activeVlcSubtitleTrack:
              (event['activeSubtitleTrack'] as num?)?.toInt() ??
                  state.activeVlcSubtitleTrack,
        );
        break;
      case 'completed':
        state = state.copyWith(playbackState: PlaybackState.completed);
        _saveCurrentPosition();
        _markWatchedIfComplete();
        if (state.currentItem?.type == MediaType.live) {
          _scheduleReconnect();
        }
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'LibVLC playback error';
        _cancelReconnectTimer();
        if (state.currentItem?.type == MediaType.live &&
            _reconnectAttempt < _maxReconnectAttempts) {
          _scheduleReconnect();
        } else {
          state = state.copyWith(
            isBuffering: false,
            playbackState: PlaybackState.failed,
            errorMessage: msg,
          );
        }
        break;
    }
  }

  // ─── Reconnection & Stall / Infinite-Buffer Guard ─────────────────────────

  void _startStallDetection() {
    _stallDetectionTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final item = state.currentItem;
      if (item == null || _isRecovering) return;

      final cfg =
          streamingManager.resolveBufferConfig(isLive: item.type == MediaType.live);

      // 1. Guard against infinite buffering / connecting spinner
      if ((state.isBuffering ||
              state.playbackState == PlaybackState.connecting ||
              state.playbackState == PlaybackState.loading) &&
          _bufferingSince != null) {
        final stuckSecs =
            DateTime.now().difference(_bufferingSince!).inSeconds;

        // Non-interruptive background SmartStream search on sustained live buffering (5s)
        if (item.type == MediaType.live &&
            tissController.hasAlternatives &&
            tissController.isAutoMode &&
            tissController.config.automaticSwitchingEnabled &&
            !_isSearchingAlternative &&
            stuckSecs >= 5) {
          unawaited(_triggerTissFailover(
            reason: 'sustained_buffering',
            interruptCurrentOnFailure: false,
          ));
          return;
        }

        if (stuckSecs >= cfg.bufferingTimeoutSecs) {
          _bufferingSince = null;
          _scheduleReconnect(reason: 'buffering_timeout');
          return;
        }
      }

      // 2. Guard against frozen playback (position not advancing while playing)
      final currentPosition = state.position;
      if (state.playbackState != PlaybackState.playing || state.isBuffering) {
        _lastObservedPosition = currentPosition;
        _stalledSeconds = 0;
        return;
      }

      // 3. TISS QualityRecoveryController: check for controlled quality upgrade
      if (item.type == MediaType.live && tissController.hasAlternatives) {
        final upgradeTarget = tissController.evaluateQualityUpgrade(
          throughputKbps:
              streamingManager.analytics.snapshot().estimatedThroughputKbps,
          bufferDuration: state.bufferDuration,
        );
        if (upgradeTarget != null) {
          unawaited(_commitTissSwitch(
            upgradeTarget,
            notification:
                'Connection improved. Returning to ${upgradeTarget.displayQuality}.',
          ));
          return;
        }
      }

      if (_lastObservedPosition == null ||
          currentPosition != _lastObservedPosition) {
        _lastObservedPosition = currentPosition;
        _stalledSeconds = 0;
        return;
      }

      _stalledSeconds += 2;
      if (_stalledSeconds >= cfg.stallTimeoutSecs) {
        _stalledSeconds = 0;
        if (item.type == MediaType.live && tissController.hasAlternatives) {
          unawaited(_triggerTissFailover(reason: 'playback_stalled'));
        } else {
          _scheduleReconnect(reason: 'playback_stalled');
        }
      }
    });
  }

  void _scheduleReconnect({String reason = 'stream_error'}) {
    // Never repeatedly restart a player that is already recovering
    if (_isRecovering) return;

    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _isRecovering = false;
      streamingManager.analytics.recordFailure(StreamFailureKind.streamUnavailable);
      state = state.copyWith(
        isBuffering: false,
        playbackState: PlaybackState.streamUnavailable,
        errorMessage:
            'Stream unavailable after $_maxReconnectAttempts recovery attempts. Tap Retry or try another source.',
      );
      _reconnectAttempt = 0;
      return;
    }

    _isRecovering = true;
    final delaySeconds =
        streamingManager.backoffDelayForAttempt(_reconnectAttempt);
    _reconnectAttempt++;
    streamingManager.analytics.recordRecoveryAttempt(_reconnectAttempt, reason);

    state = state.copyWith(
      playbackState: PlaybackState.reconnecting,
      reconnectAttempt: _reconnectAttempt,
      isBuffering: true,
      clearError: true,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      final item = state.currentItem;
      if (item == null || item.streamUrl == null) {
        _isRecovering = false;
        return;
      }
      if (state.playbackState != PlaybackState.reconnecting) {
        _isRecovering = false;
        return;
      }

      try {
        final headers = await _getHttpHeaders();
        // Force fresh Stalker session link on reconnect if needed
        if (item.playlistId != null) {
          _stalkerCredsCache.remove(item.playlistId);
        }
        final baseUrl = await _resolvePlaybackUrl(item);
        String urlToTry = baseUrl;
        // On odd live reconnect attempts, alternate between HLS (.m3u8) and TS (.ts)
        if (item.type == MediaType.live && _reconnectAttempt.isOdd) {
          if (baseUrl.toLowerCase().endsWith('.ts')) {
            urlToTry = _playbackUrlFor(item, format: LiveStreamFormat.hls);
          } else if (baseUrl.toLowerCase().endsWith('.m3u8')) {
            urlToTry = _playbackUrlFor(item, format: LiveStreamFormat.ts);
          }
        }

        // For VOD/series, resume at last known position; for Live TV, jump to live edge
        final resumeAt = item.type == MediaType.live
            ? Duration.zero
            : state.position;

        _bufferingSince = DateTime.now();
        if (_usingLibVlc) {
          await libVlcBridge.open(
            url: urlToTry,
            headers: headers,
            start: resumeAt,
          );
        } else {
          await player.open(
            Media(
              urlToTry,
              httpHeaders: headers,
              start: resumeAt > Duration.zero ? resumeAt : null,
            ),
            play: true,
          );
        }
        _isRecovering = false;
      } catch (_) {
        _isRecovering = false;
        _scheduleReconnect(reason: 'reconnect_failed');
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isRecovering = false;
  }

  Future<void> _setMpvProperty(String property, String value) async {
    try {
      await (player.platform as dynamic).setProperty(property, value);
    } catch (_) {}
  }

  Future<String> _getMpvProperty(String property) async {
    try {
      final res = await (player.platform as dynamic).getProperty(property);
      return res?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setAspectRatio(String aspect) async {
    if (_usingLibVlc) {
      await libVlcBridge.setAspectRatio(aspect);
    } else {
      await _setMpvProperty('video-aspect-override', aspect);
    }
  }

  Future<void> setVlcAudioTrack(int trackId) async {
    if (!_usingLibVlc) return;
    await libVlcBridge.setAudioTrack(trackId);
    state = state.copyWith(activeVlcAudioTrack: trackId);
  }

  Future<void> setVlcSubtitleTrack(int trackId) async {
    if (!_usingLibVlc) return;
    await libVlcBridge.setSubtitleTrack(trackId);
    state = state.copyWith(activeVlcSubtitleTrack: trackId);
  }

  Future<void> setPlaybackEngine(PlaybackEngine engine) async {
    await _preferencesLoaded;
    final target = (engine == PlaybackEngine.libVlc && LibVlcBridge.isSupported)
        ? PlaybackEngine.libVlc
        : PlaybackEngine.mediaKit;
    if (state.playbackEngine == target) return;

    final activeItem = state.currentItem;
    final wasFullscreen = state.isFullscreen;
    final resumePos = state.position;

    // Stop previous engine cleanly before switching
    try {
      await player.stop();
    } catch (_) {}
    try {
      await libVlcBridge.stop();
    } catch (_) {}

    state = state.copyWith(
      playbackEngine: target,
      clearError: true,
      vlcAudioTracks: const [],
      vlcSubtitleTracks: const [],
    );

    try {
      await _storage.savePlaylistCredentials(
        'filimu_playback_engine',
        target.name,
      );
    } catch (_) {}

    if (activeItem != null) {
      _currentOpenUrl = null;
      await playItem(
        activeItem.copyWith(positionSeconds: resumePos.inSeconds),
        startFullscreen: wasFullscreen,
      );
    }
  }

  // ─── Performance & Buffer Profiles ───────────────────────────────────────

  BufferProfile get bufferProfile => streamingManager.profile;
  List<StreamRendition> get availableRenditions =>
      streamingManager.availableRenditions;
  StreamRendition get selectedRendition => streamingManager.selectedRendition;

  Future<void> setBufferProfile(BufferProfile profile) async {
    streamingManager.setBufferProfile(profile);
    await setPlaybackProfile(profile.toLegacyProfile());
  }

  Future<void> selectQuality(StreamRendition rendition) async {
    final variantUrl = streamingManager.selectManualQuality(rendition);
    if (!_usingLibVlc) {
      if (rendition.isAuto) {
        await _setMpvProperty('hls-bitrate', 'max');
      } else if (rendition.bandwidthBps > 0) {
        await _setMpvProperty('hls-bitrate', rendition.bandwidthBps.toString());
      }
    }
    // If a specific HLS variant URI was chosen, switch seamlessly
    final item = state.currentItem;
    if (item != null && variantUrl != null && variantUrl.isNotEmpty) {
      final resumeAt = item.type == MediaType.live ? Duration.zero : state.position;
      final headers = await _getHttpHeaders();
      if (_usingLibVlc) {
        await libVlcBridge.open(url: variantUrl, headers: headers, start: resumeAt);
      } else {
        await player.open(
          Media(
            variantUrl,
            httpHeaders: headers,
            start: resumeAt > Duration.zero ? resumeAt : null,
          ),
          play: true,
        );
      }
    }
    state = state.copyWith();
  }

  Future<void> applyProfile(PlaybackProfile profile) async {
    final mapped = BufferProfileLabel.fromLegacyProfile(profile);
    streamingManager.setBufferProfile(mapped);
    state = state.copyWith(playbackProfile: profile);

    // On Android, let media_kit's VideoController manage hwdec/vo (e.g. S/W
    // rendering on emulators where MediaCodec discards frames).
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isLive = state.currentItem?.type == MediaType.live;
    final props = streamingManager.buildMpvProperties(
      isLive: isLive,
      isAndroid: isAndroid,
    );

    try {
      for (final entry in props.entries) {
        await _setMpvProperty(entry.key, entry.value);
      }
    } catch (_) {
      // setProperty may throw if player is not initialized yet — non-fatal
    }
  }

  // ─── Diagnostics ─────────────────────────────────────────────────────────

  Future<Map<String, String>> getDiagnostics() async {
    final results = <String, String>{};
    int? droppedFrames;
    int? throughputKbps;

    try {
      if (_usingLibVlc) {
        results['decoder'] = 'LibVLC (Android MediaCodec / S/W)';
        results['hardware_accelerated'] = 'true';
      } else {
        final hwdecCurrent = await _getMpvProperty('hwdec-current');
        final decoder = hwdecCurrent.isNotEmpty ? hwdecCurrent : 'software';
        results['decoder'] = decoder;
        results['hardware_accelerated'] =
            (decoder != 'no' && decoder != 'software' && decoder.isNotEmpty)
                .toString();

        final vw = player.state.width ?? 0;
        final vh = player.state.height ?? 0;
        results['resolution'] = vw > 0 ? '${vw}x$vh' : 'unknown';

        final audioParams = player.state.audioParams;
        results['audio_format'] = audioParams.format ?? 'unknown';

        final fpsStr = await _getMpvProperty('estimated-vf-fps');
        final fps = double.tryParse(fpsStr) ?? 0.0;
        results['fps'] = fps > 0 ? '${fps.toStringAsFixed(1)} fps' : 'unknown';

        final vCodec = await _getMpvProperty('video-codec');
        if (vCodec.isNotEmpty) results['video_codec'] = vCodec;

        final aCodec = await _getMpvProperty('audio-codec-name');
        if (aCodec.isNotEmpty) results['audio_codec'] = aCodec;

        final bitrateStr = await _getMpvProperty('video-bitrate');
        final bitrate = int.tryParse(bitrateStr) ?? 0;
        if (bitrate > 0) {
          results['bitrate'] = '${(bitrate / 1000).toStringAsFixed(0)} kbps';
        }

        final dropStr = await _getMpvProperty('frame-drop-count');
        droppedFrames = int.tryParse(dropStr) ?? 0;

        final cacheSpeedStr = await _getMpvProperty('cache-speed');
        final cacheSpeedBytesPerSec = double.tryParse(cacheSpeedStr) ?? 0;
        if (cacheSpeedBytesPerSec > 0) {
          throughputKbps = ((cacheSpeedBytesPerSec * 8) / 1000).round();
        }
      }
    } catch (_) {}

    streamingManager.analytics.updateRuntimeMetrics(
      droppedFrames: droppedFrames,
      throughputKbps: throughputKbps,
    );
    final snap = streamingManager.analytics.snapshot();

    results['buffer_seconds'] = state.bufferDuration.inSeconds.toString();
    results['playback_state'] = state.playbackState.displayLabel;
    results['reconnect_attempts'] = state.reconnectAttempt.toString();
    results['profile'] = streamingManager.profile.label;
    results['ttff'] =
        snap.lastStartupMs != null ? '${snap.lastStartupMs} ms' : 'measuring...';
    results['avg_startup'] = snap.averageStartupMs != null
        ? '${snap.averageStartupMs} ms'
        : 'n/a';
    if (snap.lastChannelSwitchMs != null) {
      results['channel_switch'] = '${snap.lastChannelSwitchMs} ms';
    }
    results['rebuffer_count'] = snap.rebufferCount.toString();
    results['buffering_total'] =
        '${(snap.totalBufferingMs / 1000).toStringAsFixed(1)}s';
    results['dropped_frames'] = snap.droppedFrames.toString();
    if (snap.estimatedThroughputKbps != null) {
      results['throughput'] = '${snap.estimatedThroughputKbps} kbps';
    }
    results['quality'] = snap.selectedQualityLabel;
    results['recovery_rate'] =
        '${(snap.recoverySuccessRate * 100).round()}% (${snap.recoverySuccesses}/${snap.recoveryAttempts})';
    if (snap.rootCauseHint != null) {
      results['root_cause'] = snap.rootCauseHint!;
    }
    return results;
  }

  // ─── Auto-Play Next Episode ───────────────────────────────────────────────

  /// Attempts to find the next episode for the currently playing series item.
  Future<void> _resolveNextEpisode() async {
    final item = state.currentItem;
    if (item == null || item.type != MediaType.series) return;
    if (item.playlistId == null || item.seriesProviderId == null) return;
    if (item.episodeNumber == null || item.seasonNumber == null) return;

    try {
      final currentSeason = item.seasonNumber!;
      final currentEp = item.episodeNumber!;

      final allRows = await (_db.select(_db.contentItemsTable)
            ..where((t) =>
                t.playlistId.equals(item.playlistId!) &
                t.type.equals('series')))
          .get();

      if (allRows.isEmpty) return;

      final seriesRows = allRows
          .where((r) => r.providerId.startsWith(item.seriesProviderId!))
          .toList();

      for (final row in seriesRows) {
        final matchSameSeason = RegExp(
          'S0?${currentSeason}E0?${currentEp + 1}\\b',
          caseSensitive: false,
        ).hasMatch('${row.title} ${row.providerId}');

        final matchNextSeason = RegExp(
          'S0?${currentSeason + 1}E0?1\\b',
          caseSensitive: false,
        ).hasMatch('${row.title} ${row.providerId}');

        if (matchSameSeason || matchNextSeason) {
          final nextItem = MediaItem(
            id: row.id.toString(),
            contentDbId: row.id,
            title: row.title,
            subtitle: 'S$currentSeason E${currentEp + 1}',
            streamUrl: row.streamUrl,
            posterUrl: row.posterUrl,
            type: MediaType.series,
            playlistId: row.playlistId,
            providerId: row.providerId,
            seriesProviderId: item.seriesProviderId,
            seasonNumber: matchSameSeason ? currentSeason : currentSeason + 1,
            episodeNumber: matchSameSeason ? currentEp + 1 : 1,
          );
          state = state.copyWith(nextEpisodeItem: nextItem);
          break;
        }
      }
    } catch (_) {}
  }

  void setNextEpisodeItem(MediaItem? nextItem) {
    state = state.copyWith(nextEpisodeItem: nextItem);
  }

  void clearNextEpisode() {
    state = state.copyWith(clearNextEpisode: true);
  }

  Future<void> setAutoPlay(bool enabled) async {
    state = state.copyWith(autoPlayEnabled: enabled);
    try {
      await _storage.savePlaylistCredentials(
          'filimu_autoplay_next', enabled ? 'true' : 'false');
    } catch (_) {}
  }

  Future<void> setLiveStreamFormat(LiveStreamFormat format) async {
    await _preferencesLoaded;
    final item = state.currentItem;
    final previousUrl = item == null
        ? null
        : _playbackUrlFor(item, format: state.liveStreamFormat);
    state = state.copyWith(liveStreamFormat: format);
    try {
      await _storage.savePlaylistCredentials(
        'filimu_live_stream_format',
        format.name,
      );
    } catch (_) {}

    if (item?.type == MediaType.live &&
        previousUrl != _playbackUrlFor(item!, format: format)) {
      await player.stop();
      await playItem(item, startFullscreen: state.isFullscreen);
    }
  }

  Future<void> setPlaybackProfile(PlaybackProfile profile) async {
    await _preferencesLoaded;
    await applyProfile(profile);
    try {
      await _storage.savePlaylistCredentials(
        'filimu_playback_profile',
        profile.name,
      );
    } catch (_) {}
  }

  String _playbackUrlFor(
    MediaItem item, {
    LiveStreamFormat? format,
  }) {
    final streamUrl = item.streamUrl;
    final selectedFormat = format ?? state.liveStreamFormat;
    if (item.type != MediaType.live ||
        streamUrl == null ||
        selectedFormat == LiveStreamFormat.providerDefault) {
      return streamUrl ?? '';
    }

    final uri = Uri.tryParse(streamUrl);
    if (uri == null) return streamUrl;
    final segments = uri.pathSegments;
    final liveIndex = segments.indexOf('live');
    if (liveIndex < 0 || segments.length != liveIndex + 4) return streamUrl;

    final extension = selectedFormat == LiveStreamFormat.hls ? 'm3u8' : 'ts';
    final path = uri.path.replaceFirst(
      RegExp(r'\.(?:ts|m3u8)$', caseSensitive: false),
      '.$extension',
    );
    if (path == uri.path) return streamUrl;
    return uri.replace(path: path).toString();
  }

  /// Resolves Stalker Portal `cmd` links via `create_link` when playing from a
  /// Stalker playlist, otherwise applies standard live stream format rules.
  Future<String> _resolvePlaybackUrl(MediaItem item) async {
    final raw = item.streamUrl ?? '';
    if (raw.isEmpty) return '';

    final client = _stalkerClient;
    final playlistId = item.playlistId;
    if (client != null && playlistId != null) {
      try {
        final playlist = await _db.getPlaylist(playlistId);
        if (playlist != null &&
            playlist.type == 'stalker' &&
            playlist.serverUrl != null &&
            playlist.macAddress != null) {
          var creds = _stalkerCredsCache[playlistId] ??
              StalkerCredentials(
                serverUrl: playlist.serverUrl!,
                macAddress: playlist.macAddress!,
              );
          if (creds.token == null) {
            final token = await client.handshake(creds);
            if (token != null && token.isNotEmpty) {
              creds = creds.copyWith(token: token);
              await client.getProfile(creds);
            }
            _stalkerCredsCache[playlistId] = creds;
          }

          final stalkerType = item.type == MediaType.live ? 'itv' : 'vod';
          final created = await client.createLink(
            creds,
            type: stalkerType,
            cmd: raw,
          );
          if (created != null && created.isNotEmpty) {
            return created;
          }
          final direct = StalkerClient.extractDirectUrl(raw);
          if (direct != null) return direct;
        }
      } catch (_) {
        final direct = StalkerClient.extractDirectUrl(raw);
        if (direct != null) return direct;
      }
    }

    return _playbackUrlFor(item);
  }

  // ─── TISS (Tamba Intelligent Stream Switching) ───────────────────────────

  void _showTissNotification(String message) {
    _tissNotificationTimer?.cancel();
    state = state.copyWith(tissNotification: message);
    _tissNotificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        state = state.copyWith(clearTissNotification: true);
      }
    });
  }

  Future<void> _attachTissForLiveItem(MediaItem item) async {
    if (item.type != MediaType.live ||
        item.playlistId == null ||
        item.providerId == null) {
      tissController.detach();
      return;
    }
    try {
      await _getLiveChannelsForZapping(item.playlistId!);
      final logical = _logicalByProviderId[item.providerId!];
      if (logical != null) {
        final matchingAlt = logical.alternatives.firstWhere(
          (a) => a.providerId == item.providerId,
          orElse: () => logical.primaryStream,
        );
        tissController.attachLogicalChannel(
          logical,
          initialStream: matchingAlt,
          autoMode: true,
        );
      } else {
        tissController.detach();
      }
    } catch (_) {}
  }

  /// Lightweight background reachability probe using a short HTTP GET header
  /// check (never `HEAD`, which Xtream panels reject with 404) so we can verify
  /// a backup feed is live and responsive WITHOUT interrupting active playback.
  Future<bool> _probeStreamReachable(
    String url,
    Map<String, String> headers,
  ) async {
    if (kIsWeb) return true;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final req = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 3));
      req.followRedirects = true;
      req.maxRedirects = 4;
      headers.forEach((k, v) => req.headers.set(k, v));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-65535');

      final res = await req.close().timeout(const Duration(seconds: 3));
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      client.close(force: true);
      return ok;
    } catch (_) {
      client.close(force: true);
      return false;
    }
  }

  /// Searches across all categories of the playlist for a lower-quality or
  /// backup feed of the same logical channel IN THE BACKGROUND while keeping
  /// the user's current viewing experience uninterrupted.
  ///
  /// Only switches once a responsive, verified alternative is found.
  /// When [interruptCurrentOnFailure] is `false` (buffering/stall), if no
  /// working alternative is found, the current stream continues undisturbed.
  Future<void> _triggerTissFailover({
    required String reason,
    bool isExpired = false,
    bool interruptCurrentOnFailure = false,
  }) async {
    if (_isRecovering || _isSearchingAlternative) return;
    final current = state.currentItem;
    if (current == null) return;

    final epoch = _playbackEpoch;
    final throughput =
        streamingManager.analytics.snapshot().estimatedThroughputKbps;
    final candidates = tissController.rankedFailoverCandidates(
      throughputKbps: throughput,
      isExpired: isExpired,
    );

    if (candidates.isEmpty) {
      if (interruptCurrentOnFailure) {
        _showTissNotification(
          'No backup feeds available — reconnecting stream.',
        );
        _scheduleReconnect(reason: reason);
      }
      return;
    }

    _isSearchingAlternative = true;
    StreamAlternative? verifiedTarget;
    String? preResolvedUrl;

    try {
      final headers = await _getHttpHeaders();
      final maxProbes = candidates.length < 4 ? candidates.length : 4;

      for (int i = 0; i < maxProbes; i++) {
        // Abort silently if user changed channels or closed the player
        if (epoch != _playbackEpoch || !mounted) return;

        // If playback already recovered smoothly on its own while we were
        // searching in the background, do NOT interrupt the viewer!
        if (!interruptCurrentOnFailure &&
            state.playbackState == PlaybackState.playing &&
            !state.isBuffering &&
            _stalledSeconds == 0) {
          return;
        }

        final candidate = candidates[i];
        final probeItem = current.copyWith(
          streamUrl: candidate.streamUrl,
          providerId: candidate.providerId,
        );
        final resolvedUrl = await _resolvePlaybackUrl(probeItem);
        if (epoch != _playbackEpoch || !mounted) return;

        final reachable = await _probeStreamReachable(resolvedUrl, headers);
        if (epoch != _playbackEpoch || !mounted) return;

        if (reachable) {
          verifiedTarget = candidate;
          preResolvedUrl = resolvedUrl;
          break;
        } else {
          tissController.markCandidateUnreachable(
            candidate,
            isExpired: isExpired,
          );
        }
      }
    } finally {
      _isSearchingAlternative = false;
    }

    if (epoch != _playbackEpoch || !mounted) return;

    // Final check before switching: if current playback stabilized while
    // probing, keep watching without interruption.
    if (!interruptCurrentOnFailure &&
        state.playbackState == PlaybackState.playing &&
        !state.isBuffering &&
        _stalledSeconds == 0) {
      return;
    }

    if (verifiedTarget == null) {
      if (interruptCurrentOnFailure) {
        _showTissNotification(
          'No backup feeds available — reconnecting stream.',
        );
        _scheduleReconnect(reason: reason);
      }
      return;
    }

    tissController.commitVerifiedFailover(
      verifiedTarget,
      reason: reason,
      isExpired: isExpired,
    );

    await _commitTissSwitch(
      verifiedTarget,
      preResolvedUrl: preResolvedUrl,
      notification:
          'Switched to ${verifiedTarget.displayQuality} for smoother playback.',
    );
  }

  Future<void> _commitTissSwitch(
    StreamAlternative target, {
    String? preResolvedUrl,
    String? notification,
  }) async {
    final current = state.currentItem;
    if (current == null) return;
    final epoch = _playbackEpoch;

    _isRecovering = true;
    _cancelReconnectTimer();
    _isRecovering = true;
    if (notification != null) {
      _showTissNotification(notification);
    }

    // Preserve logical channel display name, logo, and EPG metadata
    final switchedItem = current.copyWith(
      streamUrl: target.streamUrl,
      providerId: target.providerId,
    );

    try {
      final headers = await _getHttpHeaders();
      final resolvedUrl =
          preResolvedUrl ?? await _resolvePlaybackUrl(switchedItem);
      // Abort cleanly if user switched channels while failover was preparing
      if (epoch != _playbackEpoch) {
        _isRecovering = false;
        return;
      }
      _currentOpenUrl = target.streamUrl;
      _hasRenderedFirstFrame = false;
      _stalledSeconds = 0;
      _lastObservedPosition = null;
      _bufferingSince = DateTime.now();

      state = state.copyWith(
        currentItem: switchedItem,
        playbackState: PlaybackState.loading,
        isBuffering: true,
        clearError: true,
      );

      if (_usingLibVlc) {
        await libVlcBridge.open(url: resolvedUrl, headers: headers);
      } else {
        await player.open(
          Media(resolvedUrl, httpHeaders: headers),
          play: true,
        );
      }
    } catch (_) {
      _isRecovering = false;
      await _triggerTissFailover(
        reason: 'alternative_failed',
        interruptCurrentOnFailure: true,
      );
      return;
    }
    _isRecovering = false;
  }

  /// Manual TISS quality selection (`null` = Auto mode).
  Future<void> selectTissQuality(StreamAlternative? alt) async {
    final chosen = tissController.setManualQuality(alt);
    if (alt == null) {
      _showTissNotification('Quality set to Auto.');
      state = state.copyWith();
      return;
    }
    if (chosen != null) {
      await _commitTissSwitch(
        chosen,
        notification: 'Switched to ${chosen.displayQuality}.',
      );
    }
  }

  SmartStreamMode get smartStreamMode => tissController.config.mode;
  bool get automaticSwitchingEnabled =>
      tissController.config.automaticSwitchingEnabled;
  bool get autoUpgradeEnabled => tissController.config.autoUpgradeEnabled;

  Future<void> setAutomaticSwitching(bool enabled) async {
    tissController.updateConfig(
      tissController.config.copyWith(automaticSwitchingEnabled: enabled),
    );
    try {
      await _storage.savePlaylistCredentials(
        'filimu_smartstream_auto_switch',
        enabled ? 'true' : 'false',
      );
    } catch (_) {}
    state = state.copyWith();
  }

  Future<void> setSmartStreamMode(SmartStreamMode mode) async {
    tissController.setMode(mode);
    final mappedBuffer = switch (mode) {
      SmartStreamMode.balanced => BufferProfile.balanced,
      SmartStreamMode.bestQuality => BufferProfile.balanced,
      SmartStreamMode.mostStable => BufferProfile.stable,
    };
    streamingManager.setBufferProfile(mappedBuffer);
    try {
      await _storage.savePlaylistCredentials(
        'filimu_smartstream_mode',
        mode.name,
      );
    } catch (_) {}
    _showTissNotification('SmartStream: ${mode.label}');
    state = state.copyWith();
  }

  Future<void> toggleTissAutoUpgrade(bool enabled) async {
    tissController.updateConfig(
      tissController.config.copyWith(autoUpgradeEnabled: enabled),
    );
    try {
      await _storage.savePlaylistCredentials(
        'filimu_smartstream_auto_upgrade',
        enabled ? 'true' : 'false',
      );
    } catch (_) {}
    state = state.copyWith();
  }

  void toggleTissSimulatePoorNetwork(bool enabled) {
    tissController.updateConfig(
      tissController.config.copyWith(simulatePoorNetwork: enabled),
    );
    if (enabled && tissController.hasAlternatives) {
      unawaited(_triggerTissFailover(reason: 'simulated_poor_network'));
    } else {
      state = state.copyWith();
    }
  }

  // ─── Core Playback ───────────────────────────────────────────────────────

  Future<void> playItem(
    MediaItem item, {
    bool startFullscreen = false,
    bool isChannelSwitch = false,
  }) async {
    await _preferencesLoaded;
    _playbackEpoch++;
    _cancelReconnectTimer();
    _isSearchingAlternative = false;
    _reconnectAttempt = 0;
    _hasRenderedFirstFrame = false;
    _stalledSeconds = 0;

    // Guard against race condition: if same URL is being opened and still loading, skip
    if (_currentOpenUrl == item.streamUrl &&
        (state.playbackState == PlaybackState.connecting ||
            state.playbackState == PlaybackState.loading)) {
      return;
    }
    if (!isChannelSwitch) {
      await _saveCurrentPosition();
    }
    // Clear stale URL on error so retries aren't blocked
    if (state.playbackState.isError) {
      _currentOpenUrl = null;
    }
    _currentOpenUrl = item.streamUrl;

    final resumeSeconds = item.type == MediaType.live
        ? 0
        : (item.positionSeconds > 0
            ? item.positionSeconds
            : await _loadSavedPosition(item) ?? 0);

    _bufferingSince = DateTime.now();
    state = state.copyWith(
      currentItem: item.copyWith(positionSeconds: resumeSeconds),
      playbackState: PlaybackState.connecting,
      isMiniPlayerVisible: !startFullscreen,
      isFullscreen: startFullscreen,
      position: Duration(seconds: resumeSeconds),
      clearError: true,
      clearNextEpisode: true,
      isBuffering: true,
    );

    if (item.streamUrl == null || item.streamUrl!.isEmpty) {
      _bufferingSince = null;
      state = state.copyWith(
        isBuffering: false,
        playbackState: PlaybackState.streamUnavailable,
        errorMessage: 'No stream URL is available for this item.',
      );
      return;
    }

    try {
      if (item.type == MediaType.live) {
        await _attachTissForLiveItem(item);
      } else {
        tissController.detach();
      }
      final headers = await _getHttpHeaders();
      final resolvedUrl = await _resolvePlaybackUrl(item);

      // Pre-flight validation + HLS ABR rendition discovery
      final validation = await streamingManager.prepareStream(
        resolvedUrl,
        headers: headers,
        isChannelSwitch: isChannelSwitch,
      );

      // Abort if user switched to another stream while validating
      if (_currentOpenUrl != item.streamUrl) return;

      if (!validation.isValid) {
        _bufferingSince = null;
        final errState = switch (validation.failureKind) {
          StreamFailureKind.unsupportedFormat =>
            PlaybackState.unsupportedFormat,
          StreamFailureKind.streamUnavailable ||
          StreamFailureKind.expiredOrUnauthorized =>
            PlaybackState.streamUnavailable,
          _ => PlaybackState.failed,
        };
        state = state.copyWith(
          isBuffering: false,
          playbackState: errState,
          errorMessage: validation.userMessage ?? 'Stream unavailable.',
        );
        return;
      }

      state = state.copyWith(playbackState: PlaybackState.loading);

      if (_usingLibVlc) {
        try {
          await player.stop();
        } catch (_) {}
        await libVlcBridge.open(
          url: resolvedUrl,
          headers: headers,
          start: resumeSeconds > 0
              ? Duration(seconds: resumeSeconds)
              : Duration.zero,
        );
        await libVlcBridge.setVolume(state.volume);
        await libVlcBridge.setRate(state.playbackRate);
      } else {
        try {
          await libVlcBridge.stop();
        } catch (_) {}
        await applyProfile(state.playbackProfile);
        await player.open(
          Media(
            resolvedUrl,
            httpHeaders: headers,
            start: resumeSeconds > 0 ? Duration(seconds: resumeSeconds) : null,
          ),
          play: true,
        );
        try {
          await player.setRate(state.playbackRate);
        } catch (_) {}
      }

      unawaited(_persistEpisodeForContinueWatching(item));
      unawaited(_recordRecentlyViewed(item));
    } catch (e) {
      _bufferingSince = null;
      final kind = StreamValidator.classifyPlayerError(e.toString());
      streamingManager.analytics.recordFailure(kind);
      state = state.copyWith(
        isBuffering: false,
        playbackState: kind == StreamFailureKind.unsupportedFormat
            ? PlaybackState.unsupportedFormat
            : PlaybackState.failed,
        errorMessage: _friendlyError(e.toString()),
      );
    }
  }

  /// Fast channel switch: reuses the active player instance directly (no
  /// redundant stop/recreate) and persists position asynchronously.
  Future<void> switchStream(MediaItem item) async {
    if (state.currentItem?.type == MediaType.live &&
        item.type == MediaType.live &&
        state.currentItem?.providerId != item.providerId) {
      _previousLiveChannel = state.currentItem;
    }
    unawaited(_saveCurrentPosition());
    _cancelReconnectTimer();
    _reconnectAttempt = 0;
    await playItem(
      item,
      startFullscreen: state.isFullscreen,
      isChannelSwitch: true,
    );
  }

  Future<void> playPreviousWatchedChannel() async {
    final prev = _previousLiveChannel;
    if (prev == null) return;
    await switchStream(prev);
  }

  Future<List<ContentItemsTableData>> _getLiveChannelsForZapping(
      String playlistId) async {
    if (_cachedLivePlaylistId == playlistId && _cachedLiveChannels.isNotEmpty) {
      return _cachedLiveChannels;
    }
    final channels = await (_db.select(_db.contentItemsTable)
          ..where((t) =>
              t.playlistId.equals(playlistId) & t.type.equals('live'))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
        .get();
    _cachedLivePlaylistId = playlistId;
    _cachedLiveChannels = channels;
    final grouped = ChannelGroupingEngine.groupChannels(channels);
    final lookup = <String, LogicalChannel>{};
    for (final logical in grouped) {
      for (final alt in logical.alternatives) {
        lookup[alt.providerId] = logical;
      }
    }
    _logicalByProviderId = lookup;
    return channels;
  }

  Future<void> playNextChannel() async {
    final item = state.currentItem;
    if (item == null ||
        item.type != MediaType.live ||
        item.playlistId == null) {
      return;
    }
    try {
      final channels = await _getLiveChannelsForZapping(item.playlistId!);
      if (channels.isEmpty) return;
      final currentIndex =
          channels.indexWhere((c) => c.providerId == item.providerId);
      final nextIndex = (currentIndex + 1) % channels.length;
      final target = channels[nextIndex];
      final targetItem = MediaItem(
        id: target.id.toString(),
        contentDbId: target.id,
        title: target.title,
        streamUrl: target.streamUrl,
        posterUrl: target.posterUrl,
        type: MediaType.live,
        playlistId: target.playlistId,
        providerId: target.providerId,
      );
      await switchStream(targetItem);
    } catch (_) {}
  }

  Future<void> playPreviousChannel() async {
    final item = state.currentItem;
    if (item == null ||
        item.type != MediaType.live ||
        item.playlistId == null) {
      return;
    }
    try {
      final channels = await _getLiveChannelsForZapping(item.playlistId!);
      if (channels.isEmpty) return;
      final currentIndex =
          channels.indexWhere((c) => c.providerId == item.providerId);
      final prevIndex = (currentIndex - 1 + channels.length) % channels.length;
      final target = channels[prevIndex];
      final targetItem = MediaItem(
        id: target.id.toString(),
        contentDbId: target.id,
        title: target.title,
        streamUrl: target.streamUrl,
        posterUrl: target.posterUrl,
        type: MediaType.live,
        playlistId: target.playlistId,
        providerId: target.providerId,
      );
      await switchStream(targetItem);
    } catch (_) {}
  }

  // ─── Playback Controls ───────────────────────────────────────────────────

  Future<void> togglePlayPause() async {
    if (_usingLibVlc) {
      await libVlcBridge.togglePlayPause();
      return;
    }
    await player.playOrPause();
    if (!player.state.playing) {
      await _saveCurrentPosition();
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(playbackState: PlaybackState.seeking, position: position);
    if (_usingLibVlc) {
      await libVlcBridge.seek(position);
    } else {
      await player.seek(position);
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 100.0);
    if (_usingLibVlc) {
      await libVlcBridge.setVolume(clamped);
    } else {
      await player.setVolume(clamped);
    }
    state = state.copyWith(volume: clamped, isMuted: clamped == 0);
  }

  Future<void> toggleMute() async {
    if (state.isMuted || state.volume == 0) {
      await setVolume(100.0);
    } else {
      await setVolume(0.0);
    }
  }

  Future<void> setPlaybackRate(double rate) async {
    if (_usingLibVlc) {
      await libVlcBridge.setRate(rate);
    } else {
      await player.setRate(rate);
    }
    state = state.copyWith(playbackRate: rate);
  }

  // ─── UI Navigation ───────────────────────────────────────────────────────

  void openFullscreen() {
    state = state.copyWith(isFullscreen: true, isMiniPlayerVisible: false);
  }

  void minimizePlayer() {
    if (state.currentItem == null) return;
    state = state.copyWith(isFullscreen: false, isMiniPlayerVisible: true);
  }

  Future<void> closePlayer() async {
    _cancelReconnectTimer();
    _currentOpenUrl = null;
    final saveFuture = _saveCurrentPosition();
    state = state.copyWith(
      isMiniPlayerVisible: false,
      isFullscreen: false,
      isPlaying: false,
      isBuffering: false,
      position: Duration.zero,
      duration: Duration.zero,
      currentItem: null,
      playbackState: PlaybackState.idle,
      clearError: true,
      clearNextEpisode: true,
      vlcAudioTracks: const [],
      vlcSubtitleTracks: const [],
    );
    try {
      await saveFuture;
      await player.stop();
      await libVlcBridge.stop();
    } catch (_) {}
  }

  Future<void> closeMiniPlayer() => closePlayer();

  // ─── Persistence ─────────────────────────────────────────────────────────

  void _startPositionSaveTimer() {
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _saveCurrentPosition();
    });
  }

  Future<void> _saveCurrentPosition() async {
    final item = state.currentItem;
    if (item == null) return;
    if (item.type == MediaType.live) return;
    if (state.playbackState == PlaybackState.initializing ||
        state.playbackState == PlaybackState.loading) {
      return;
    }

    final position = _usingLibVlc ? state.position : player.state.position;
    final duration = _usingLibVlc ? state.duration : player.state.duration;
    if (position == Duration.zero) return;

    try {
      final playlistId = item.playlistId;
      if (playlistId == null || item.providerId == null) return;

      await _db.savePlaybackPosition(
        PlaybackPositionsTableCompanion(
          playlistId: drift.Value(playlistId),
          contentProviderId: drift.Value(item.providerId!),
          contentType: drift.Value(item.type == MediaType.series ||
                  item.type == MediaType.episode
              ? 'episode'
              : 'vod'),
          seriesProviderId: drift.Value(item.seriesProviderId),
          seasonNumber: drift.Value(item.seasonNumber),
          episodeNumber: drift.Value(item.episodeNumber),
          positionSeconds: drift.Value(position.inSeconds),
          durationSeconds: drift.Value(
            duration.inSeconds > 0 ? duration.inSeconds : null,
          ),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (error) {
      debugPrint('Failed to save playback position: $error');
    }
  }

  Future<void> _markWatchedIfComplete() async {
    final item = state.currentItem;
    if (item == null) return;
    final dur = state.duration;
    final pos = state.position;
    if (dur.inSeconds < 30) return;
    if (pos.inSeconds < dur.inSeconds * 0.9) return;

    try {
      final playlistId = item.playlistId;
      if (playlistId == null || item.providerId == null) return;
      // Save at 100% to mark watched (position == duration)
      await _db.savePlaybackPosition(
        PlaybackPositionsTableCompanion(
          playlistId: drift.Value(playlistId),
          contentProviderId: drift.Value(item.providerId!),
          contentType: drift.Value(
              item.type == MediaType.series ? 'episode' : 'vod'),
          seriesProviderId: drift.Value(item.seriesProviderId),
          seasonNumber: drift.Value(item.seasonNumber),
          episodeNumber: drift.Value(item.episodeNumber),
          positionSeconds: drift.Value(dur.inSeconds), // mark as completed
          durationSeconds: drift.Value(dur.inSeconds),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (_) {}
  }

  Future<int?> _loadSavedPosition(MediaItem item) async {
    if (item.type == MediaType.live) return null;
    if (item.playlistId == null || item.providerId == null) return null;

    try {
      final row = await (_db.select(_db.playbackPositionsTable)
            ..where((t) =>
                t.playlistId.equals(item.playlistId!) &
                t.contentProviderId.equals(item.providerId!) &
                t.contentType.equals(
                  item.type == MediaType.series ||
                          item.type == MediaType.episode
                      ? 'episode'
                      : 'vod',
                )))
          .getSingleOrNull();
      final pos = row?.positionSeconds;
      final dur = row?.durationSeconds;
      // Don't resume if already watched (>=90%)
      if (pos != null && dur != null && dur > 0 && pos >= dur * 0.9) {
        return null;
      }
      return pos;
    } catch (error) {
      debugPrint('Failed to load playback position: $error');
      return null;
    }
  }

  // ─── Recently Viewed ─────────────────────────────────────────────────────

  Future<void> _recordRecentlyViewed(MediaItem item) async {
    if (item.contentDbId == null || item.playlistId == null) return;
    try {
      final entry = RecentlyViewedTableCompanion(
        playlistId: drift.Value(item.playlistId!),
        contentId: drift.Value(item.contentDbId!),
        viewedAt: drift.Value(DateTime.now()),
      );
      await _db.into(_db.recentlyViewedTable).insert(
            entry,
            onConflict: drift.DoUpdate(
              (_) => entry,
              target: [
                _db.recentlyViewedTable.playlistId,
                _db.recentlyViewedTable.contentId,
              ],
            ),
          );
    } catch (_) {}
  }

  Future<void> _persistEpisodeForContinueWatching(MediaItem item) async {
    if (item.type != MediaType.series ||
        item.playlistId == null ||
        item.providerId == null) {
      return;
    }

    try {
      final entry = ContentItemsTableCompanion(
        playlistId: drift.Value(item.playlistId!),
        title: drift.Value(item.title),
        type: const drift.Value('series'),
        providerId: drift.Value(item.providerId!),
        streamUrl: drift.Value(item.streamUrl),
        containerExtension: const drift.Value(null),
        posterUrl: drift.Value(item.posterUrl),
        backdropUrl: drift.Value(item.backdropUrl),
      );
      await _db.into(_db.contentItemsTable).insert(
            entry,
            onConflict: drift.DoUpdate(
              (_) => entry,
              target: [
                _db.contentItemsTable.playlistId,
                _db.contentItemsTable.type,
                _db.contentItemsTable.providerId,
              ],
            ),
          );
    } catch (error) {
      debugPrint('Failed to save series episode for continue watching: $error');
    }
  }

  // ─── HTTP Headers ─────────────────────────────────────────────────────────

  Future<Map<String, String>> _getHttpHeaders() async {
    if (_cachedHeaders != null) return _cachedHeaders!;
    String ua = 'VLC/3.0.18 LibVLC/3.0.18';
    String? ref;
    try {
      final customUa =
          await _storage.getPlaylistCredentials('filimu_custom_user_agent');
      if (customUa != null && customUa.trim().isNotEmpty) {
        ua = customUa.trim();
      }
      final customRef =
          await _storage.getPlaylistCredentials('filimu_custom_referer');
      if (customRef != null && customRef.trim().isNotEmpty) {
        ref = customRef.trim();
      }
    } catch (_) {}
    final headers = <String, String>{
      'User-Agent': ua,
      'Accept': '*/*',
    };
    if (ref != null && ref.isNotEmpty) headers['Referer'] = ref;
    _cachedHeaders = headers;
    return headers;
  }

  /// Clears cached HTTP headers & live channel zapping list (e.g. after
  /// updating playlist or custom User-Agent in Settings).
  void invalidateRuntimeCaches() {
    _cachedHeaders = null;
    _cachedLivePlaylistId = null;
    _cachedLiveChannels = const [];
  }

  // ─── Error Helpers ────────────────────────────────────────────────────────

  String _friendlyError(String raw) {
    if (raw.contains('403') || raw.contains('Forbidden')) {
      return 'Access denied (403). Your stream credentials may have expired.';
    }
    if (raw.contains('404') || raw.contains('Not Found')) {
      return 'Stream not found (404). The channel or video may be unavailable.';
    }
    if (raw.contains('timeout') || raw.contains('Timeout')) {
      return 'Connection timed out. Check your internet connection and try again.';
    }
    if (raw.contains('Failed to recognize file format')) {
      return 'Could not recognize stream format. The provider stream may be offline or unsupported. Tap Retry or try another source.';
    }
    if (raw.contains('unsupported') || raw.contains('codec')) {
      return 'Unsupported stream format or codec.';
    }
    if (raw.contains('network') || raw.contains('Network')) {
      return 'Network error. Check your internet connection.';
    }
    if (raw.length > 200) return '${raw.substring(0, 200)}...';
    return raw;
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      unawaited(_saveCurrentPosition());
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseAndSaveForBackground());
    }
  }

  Future<void> _pauseAndSaveForBackground() async {
    if (_usingLibVlc) {
      await libVlcBridge.pause();
    } else if (_player != null) {
      await _player!.pause();
    }
    await _saveCurrentPosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSaveTimer?.cancel();
    _stallDetectionTimer?.cancel();
    _tissNotificationTimer?.cancel();
    _cancelReconnectTimer();
    unawaited(_saveCurrentPosition());
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player?.dispose();
    _player = null;
    _videoController = null;
    _playerInitialized = false;
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  return PlayerController(db, storage, dio: apiClient.dio);
});
