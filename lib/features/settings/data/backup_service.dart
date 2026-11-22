import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/security/secure_storage_service.dart';

class BackupExportResult {
  final String? filePath;
  final bool savedToDownloads;
  final bool cancelled;

  const BackupExportResult({
    this.filePath,
    this.savedToDownloads = false,
    this.cancelled = false,
  });
}

class BackupImportResult {
  final int playlistsCount;
  final int favoritesCount;
  final bool settingsRestored;
  final bool? forceTvMode;

  const BackupImportResult({
    required this.playlistsCount,
    required this.favoritesCount,
    required this.settingsRestored,
    this.forceTvMode,
  });
}

class BackupService {
  final AppDatabase _db;
  final SecureStorageService _storage;

  BackupService(this._db, this._storage);

  /// Exports all playlists, favorites, and settings into a JSON string.
  Future<String> exportBackupJson() async {
    final playlists = await _db.getAllPlaylists();
    final allFavorites = await (_db.select(_db.favoritesTable)).get();

    final exportPlaylists = <Map<String, dynamic>>[];
    for (final pItem in playlists) {
      final creds = await _storage.getPlaylistCredentials(pItem.id);
      exportPlaylists.add({
        'id': pItem.id,
        'name': pItem.name,
        'type': pItem.type,
        'url': pItem.url,
        'filePath': pItem.filePath,
        'serverUrl': pItem.serverUrl,
        'username': pItem.username,
        'macAddress': pItem.macAddress,
        'autoRefresh': pItem.autoRefresh,
        'channelCount': pItem.channelCount,
        'position': pItem.position,
        'credentials': creds,
      });
    }

    final exportFavorites = allFavorites
        .map((f) => {
              'playlistId': f.playlistId,
              'providerId': f.providerId,
              'type': f.type,
              'title': f.title,
              'posterUrl': f.posterUrl,
              'backdropUrl': f.backdropUrl,
              'position': f.position,
            })
        .toList();

    final tmdbKey = await _storage.getPlaylistCredentials('filimu_tmdb_api_key');
    final tmdbLang =
        await _storage.getPlaylistCredentials('filimu_tmdb_language');
    final tmdbCountry =
        await _storage.getPlaylistCredentials('filimu_tmdb_country');
    final customUa =
        await _storage.getPlaylistCredentials('filimu_custom_user_agent');
    final customRef =
        await _storage.getPlaylistCredentials('filimu_custom_referer');
    final forceTvMode =
        await _storage.getPlaylistCredentials('filimu_force_tv_mode');
    final playbackEngine =
        await _storage.getPlaylistCredentials('filimu_playback_engine');
    final playbackProfile =
        await _storage.getPlaylistCredentials('filimu_playback_profile');
    final liveStreamFormat =
        await _storage.getPlaylistCredentials('filimu_live_stream_format');
    final autoPlayNext =
        await _storage.getPlaylistCredentials('filimu_autoplay_next');
    final smartStreamMode =
        await _storage.getPlaylistCredentials('filimu_smartstream_mode');
    final smartStreamAutoSwitch = await _storage
        .getPlaylistCredentials('filimu_smartstream_auto_switch');
    final smartStreamAutoUpgrade = await _storage
        .getPlaylistCredentials('filimu_smartstream_auto_upgrade');

    final payload = {
      'version': '1.1',
      'app': 'Tamba IPTV',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'playlists': exportPlaylists,
      'favorites': exportFavorites,
      'settings': {
        'tmdbApiKey': tmdbKey,
        'tmdbLanguage': tmdbLang,
        'tmdbCountry': tmdbCountry,
        'customUserAgent': customUa,
        'customReferer': customRef,
        'forceTvMode': forceTvMode,
        'playbackEngine': playbackEngine,
        'playbackProfile': playbackProfile,
        'liveStreamFormat': liveStreamFormat,
        'autoPlayNext': autoPlayNext,
        'smartStreamMode': smartStreamMode,
        'smartStreamAutoSwitch': smartStreamAutoSwitch,
        'smartStreamAutoUpgrade': smartStreamAutoUpgrade,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Generates a backup JSON and saves it directly into the device's Downloads
  /// folder so it is easy to locate when restoring on mobile, desktop, or Smart TV.
  Future<BackupExportResult> saveBackupToDownloads() async {
    final jsonContent = await exportBackupJson();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = 'tamba_iptv_backup_$dateStr.json';
    final bytes = Uint8List.fromList(utf8.encode(jsonContent));

    if (!kIsWeb && Platform.isAndroid) {
      // 1. Try direct write to the public Android Downloads directory first.
      for (final candidate in const [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ]) {
        try {
          final dir = Directory(candidate);
          if (await dir.exists()) {
            final file = File(p.join(dir.path, fileName));
            await file.writeAsBytes(bytes, flush: true);
            return BackupExportResult(
              filePath: file.path,
              savedToDownloads: true,
            );
          }
        } catch (_) {
          // Scoped storage on Android 11+ may block direct write — fall through to SAF.
        }
      }

      // 2. Use Android SAF save dialog (defaults to Downloads, no storage permission needed).
      try {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Tamba IPTV Backup',
          fileName: fileName,
          bytes: bytes,
        );
        if (savedPath == null || savedPath.isEmpty) {
          return const BackupExportResult(cancelled: true);
        }
        return BackupExportResult(
          filePath: savedPath,
          savedToDownloads: true,
        );
      } catch (_) {
        // Some Android TV builds omit DocumentsUI — fall through to app external storage.
      }

      // 3. Fallback to app-specific external Download directory or documents directory.
      final extDir = await getExternalStorageDirectory();
      final fallbackBase = extDir ?? await getApplicationDocumentsDirectory();
      final downloadSubDir = Directory(p.join(fallbackBase.path, 'Download'));
      if (!await downloadSubDir.exists()) {
        await downloadSubDir.create(recursive: true);
      }
      final fallbackFile = File(p.join(downloadSubDir.path, fileName));
      await fallbackFile.writeAsBytes(bytes, flush: true);
      return BackupExportResult(
        filePath: fallbackFile.path,
        savedToDownloads: false,
      );
    }

    // Desktop (Windows / macOS / Linux) & iOS: prefer the OS Downloads folder.
    Directory? targetDir;
    bool isDownloads = false;
    try {
      targetDir = await getDownloadsDirectory();
      if (targetDir != null) {
        isDownloads = true;
      }
    } catch (_) {
      targetDir = null;
    }

    targetDir ??= await getApplicationDocumentsDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final backupFile = File(p.join(targetDir.path, fileName));
    await backupFile.writeAsBytes(bytes, flush: true);
    return BackupExportResult(
      filePath: backupFile.path,
      savedToDownloads: isDownloads,
    );
  }

  /// Imports a backup JSON string and returns the number of playlists restored.
  Future<int> importBackupJson(String jsonString) async {
    final result = await importBackupDetailed(jsonString);
    return result.playlistsCount;
  }

  /// Imports a backup JSON string and restores playlists, credentials, favorites,
  /// and all saved application settings.
  Future<BackupImportResult> importBackupDetailed(String jsonString) async {
    final dynamic decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid backup file: expected a Tamba IPTV JSON object.',
      );
    }
    if (!decoded.containsKey('playlists') &&
        !decoded.containsKey('favorites') &&
        !decoded.containsKey('settings')) {
      throw const FormatException(
        'Selected JSON file is not a valid Tamba IPTV backup.',
      );
    }

    final Map<String, dynamic> data = decoded;
    int importedPlaylists = 0;
    int importedFavorites = 0;
    bool settingsRestored = false;
    bool? restoredForceTvMode;

    // 1. Restore Playlists & Credentials
    if (data['playlists'] is List) {
      for (final pItem in data['playlists'] as List) {
        if (pItem is Map) {
          final id = pItem['id']?.toString();
          if (id == null || id.isEmpty) continue;

          await _db.insertPlaylist(
            PlaylistsTableCompanion(
              id: Value(id),
              name: Value(pItem['name']?.toString() ?? 'Restored Playlist'),
              type: Value(pItem['type']?.toString() ?? 'm3u_url'),
              url: Value(pItem['url']?.toString()),
              filePath: Value(pItem['filePath']?.toString()),
              serverUrl: Value(pItem['serverUrl']?.toString()),
              username: Value(pItem['username']?.toString()),
              macAddress: Value(pItem['macAddress']?.toString()),
              autoRefresh: Value(pItem['autoRefresh'] == true),
              channelCount: Value(pItem['channelCount'] is int
                  ? pItem['channelCount'] as int
                  : 0),
              position:
                  Value(pItem['position'] is int ? pItem['position'] as int : 0),
            ),
          );

          final creds = pItem['credentials']?.toString();
          if (creds != null && creds.isNotEmpty) {
            await _storage.savePlaylistCredentials(id, creds);
          }
          importedPlaylists++;
        }
      }
    }

    // 2. Restore Favorites
    if (data['favorites'] is List) {
      for (final f in data['favorites'] as List) {
        if (f is Map) {
          final playlistId = f['playlistId']?.toString();
          final providerId = f['providerId']?.toString();
          final type = f['type']?.toString();
          final title = f['title']?.toString();

          if (playlistId != null &&
              providerId != null &&
              type != null &&
              title != null) {
            await _db.into(_db.favoritesTable).insertOnConflictUpdate(
              FavoritesTableCompanion(
                playlistId: Value(playlistId),
                providerId: Value(providerId),
                type: Value(type),
                title: Value(title),
                posterUrl: Value(f['posterUrl']?.toString()),
                backdropUrl: Value(f['backdropUrl']?.toString()),
                position:
                    Value(f['position'] is int ? f['position'] as int : 0),
              ),
            );
            importedFavorites++;
          }
        }
      }
    }

    // 3. Restore Settings
    if (data['settings'] is Map) {
      final s = data['settings'] as Map;
      const keyMap = <String, String>{
        'tmdbApiKey': 'filimu_tmdb_api_key',
        'tmdbLanguage': 'filimu_tmdb_language',
        'tmdbCountry': 'filimu_tmdb_country',
        'customUserAgent': 'filimu_custom_user_agent',
        'customReferer': 'filimu_custom_referer',
        'forceTvMode': 'filimu_force_tv_mode',
        'playbackEngine': 'filimu_playback_engine',
        'playbackProfile': 'filimu_playback_profile',
        'liveStreamFormat': 'filimu_live_stream_format',
        'autoPlayNext': 'filimu_autoplay_next',
        'smartStreamMode': 'filimu_smartstream_mode',
        'smartStreamAutoSwitch': 'filimu_smartstream_auto_switch',
        'smartStreamAutoUpgrade': 'filimu_smartstream_auto_upgrade',
      };

      for (final entry in keyMap.entries) {
        final rawVal = s[entry.key];
        if (rawVal != null) {
          final strVal = rawVal.toString();
          await _storage.savePlaylistCredentials(entry.value, strVal);
          settingsRestored = true;
          if (entry.key == 'forceTvMode') {
            restoredForceTvMode = strVal == 'true';
          }
        }
      }
    }

    return BackupImportResult(
      playlistsCount: importedPlaylists,
      favoritesCount: importedFavorites,
      settingsRestored: settingsRestored,
      forceTvMode: restoredForceTvMode,
    );
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  return BackupService(db, storage);
});
