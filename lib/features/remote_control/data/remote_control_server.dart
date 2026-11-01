import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../player/data/player_controller.dart';

class RemoteControlServer {
  final Ref _ref;
  HttpServer? _server;
  int _port = 8383;

  RemoteControlServer(this._ref);

  int get port => _port;
  bool get isRunning => _server != null;

  Future<void> start({int port = 8383}) async {
    if (_server != null) return;
    _port = port;

    final router = Router();

    // API: Player Status
    router.get('/api/status', (Request request) {
      final state = _ref.read(playerControllerProvider);
      final json = {
        'isPlaying': state.isPlaying,
        'title': state.currentItem?.title ?? 'No Media Playing',
        'type': state.currentItem?.type.name ?? 'none',
        'volume': state.volume,
        'positionSeconds': state.position.inSeconds,
        'durationSeconds': state.duration.inSeconds,
      };
      return Response.ok(
        jsonEncode(json),
        headers: {'content-type': 'application/json'},
      );
    });

    // API: Toggle Play/Pause
    router.post('/api/play-pause', (Request request) async {
      await _ref.read(playerControllerProvider.notifier).togglePlayPause();
      return Response.ok(jsonEncode({'success': true}),
          headers: {'content-type': 'application/json'});
    });

    // API: Volume
    router.post('/api/volume', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final volume = (data['volume'] as num).toDouble();
      await _ref.read(playerControllerProvider.notifier).setVolume(volume);
      return Response.ok(jsonEncode({'success': true}),
          headers: {'content-type': 'application/json'});
    });

    // Web Remote Control UI
    router.get('/', (Request request) {
      const html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Tamba IPTV Remote</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #0F0F11;
      color: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }
    .card {
      background: #18181B;
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 24px;
      padding: 32px 24px;
      width: 100%;
      max-width: 360px;
      text-align: center;
      box-shadow: 0 20px 40px rgba(0,0,0,0.6);
    }
    .logo {
      color: #E50914;
      font-size: 22px;
      font-weight: 900;
      letter-spacing: 2px;
      margin-bottom: 24px;
    }
    .title {
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .status {
      font-size: 13px;
      color: rgba(255,255,255,0.5);
      margin-bottom: 32px;
    }
    .controls {
      display: flex;
      justify-content: center;
      gap: 18px;
      align-items: center;
      margin-bottom: 32px;
    }
    .btn {
      background: rgba(255,255,255,0.1);
      border: none;
      color: #fff;
      border-radius: 50%;
      width: 54px;
      height: 54px;
      font-size: 20px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
    }
    .btn-play {
      background: #E50914;
      width: 68px;
      height: 68px;
      font-size: 26px;
    }
    .btn:active {
      transform: scale(0.92);
    }
    .volume-slider {
      width: 100%;
      accent-color: #E50914;
      height: 6px;
    }
    .label {
      font-size: 12px;
      color: rgba(255,255,255,0.4);
      margin-top: 8px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">FILIMU PLUS</div>
    <div class="title" id="title">Loading...</div>
    <div class="status" id="status">Connecting to player...</div>

    <div class="controls">
      <button class="btn btn-play" onclick="togglePlay()" id="playBtn">▶</button>
    </div>

    <div>
      <input type="range" min="0" max="100" value="100" class="volume-slider" oninput="setVolume(this.value)">
      <div class="label">Volume</div>
    </div>
  </div>

  <script>
    async function update() {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        document.getElementById('title').innerText = data.title;
        document.getElementById('status').innerText = data.isPlaying ? 'Now Playing' : 'Paused';
        document.getElementById('playBtn').innerText = data.isPlaying ? '⏸' : '▶';
      } catch (e) {}
    }

    async function togglePlay() {
      await fetch('/api/play-pause', { method: 'POST' });
      update();
    }

    async function setVolume(val) {
      await fetch('/api/volume', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ volume: parseFloat(val) })
      });
    }

    setInterval(update, 2000);
    update();
  </script>
</body>
</html>''';
      return Response.ok(html, headers: {'content-type': 'text/html'});
    });

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    } catch (_) {
      // In case port is already in use, try fallback
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
      _port = _server!.port;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static Future<String> getLocalIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return 'localhost';
  }
}

final remoteControlServerProvider = Provider<RemoteControlServer>((ref) {
  final server = RemoteControlServer(ref);
  server.start();
  ref.onDispose(() => server.stop());
  return server;
});
