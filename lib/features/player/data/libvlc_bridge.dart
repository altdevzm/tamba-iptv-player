import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LibVlcTrack {
  final int id;
  final String name;

  const LibVlcTrack({required this.id, required this.name});

  factory LibVlcTrack.fromMap(Map<dynamic, dynamic> map) {
    return LibVlcTrack(
      id: (map['id'] as num?)?.toInt() ?? -1,
      name: map['name']?.toString() ?? 'Unknown',
    );
  }
}

/// Dart bridge to the bundled native Android LibVLC engine (`LibVlcPlayerPlugin`).
class LibVlcBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('tamba_iptv/libvlc');
  static const EventChannel _eventChannel =
      EventChannel('tamba_iptv/libvlc_events');
  static const String viewType = 'tamba_iptv/libvlc_view';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<String, dynamic>> get events {
    if (!isSupported) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return const <String, dynamic>{};
    });
  }

  Future<void> open({
    required String url,
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
    bool hardwareDecoding = true,
  }) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('open', {
      'url': url,
      'headers': headers,
      'startMs': start.inMilliseconds,
      'hardwareDecoding': hardwareDecoding,
    });
  }

  Future<void> play() async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('play');
  }

  Future<void> pause() async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('pause');
  }

  Future<void> togglePlayPause() async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('togglePlayPause');
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('stop');
  }

  Future<void> seek(Duration position) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('seek', {
      'positionMs': position.inMilliseconds.clamp(0, 1 << 50),
    });
  }

  Future<void> setVolume(double volume) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('setVolume', {
      'volume': volume.round().clamp(0, 100),
    });
  }

  Future<void> setRate(double rate) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('setRate', {
      'rate': rate.clamp(0.25, 4.0),
    });
  }

  Future<void> setAudioTrack(int id) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('setAudioTrack', {'id': id});
  }

  Future<void> setSubtitleTrack(int id) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('setSubtitleTrack', {'id': id});
  }

  Future<void> setAspectRatio(String? aspectRatio) async {
    if (!isSupported) return;
    await _methodChannel.invokeMethod<void>('setAspectRatio', {
      'aspectRatio': aspectRatio ?? '',
    });
  }
}

/// Pure native LibVLC video surface (no built-in VLC UI controls).
class LibVlcVideoSurface extends StatelessWidget {
  const LibVlcVideoSurface({super.key});

  @override
  Widget build(BuildContext context) {
    if (!LibVlcBridge.isSupported) {
      return const ColoredBox(color: Colors.black);
    }
    return const ColoredBox(
      color: Colors.black,
      child: AndroidView(
        viewType: LibVlcBridge.viewType,
        creationParamsCodec: StandardMessageCodec(),
      ),
    );
  }
}
