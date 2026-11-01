import 'dart:io';

class ExternalPlayerService {
  /// Launches stream URL in system VLC player
  static Future<bool> openInVlc(String streamUrl, {String? userAgent, String? referer}) async {
    try {
      final args = <String>[streamUrl];
      if (userAgent != null && userAgent.isNotEmpty) {
        args.add('--http-user-agent=$userAgent');
      }
      if (referer != null && referer.isNotEmpty) {
        args.add('--http-referrer=$referer');
      }

      await Process.start('vlc', args, mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Launches stream URL in system MPV standalone player
  static Future<bool> openInMpv(String streamUrl, {String? userAgent, String? referer}) async {
    try {
      final args = <String>[streamUrl];
      if (userAgent != null && userAgent.isNotEmpty) {
        args.add('--user-agent=$userAgent');
      }
      if (referer != null && referer.isNotEmpty) {
        args.add('--referrer=$referer');
      }

      await Process.start('mpv', args, mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens an external URL (such as a YouTube trailer or website) in the system default browser
  static Future<bool> openUrl(String url) async {
    try {
      if (Platform.isLinux) {
        await Process.start('xdg-open', [url]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.start('open', [url]);
        return true;
      } else if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', url]);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

