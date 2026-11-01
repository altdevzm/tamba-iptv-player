import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/security/secure_storage_service.dart';

class BackupService {
  final AppDatabase _db;
  final SecureStorageService _storage;

  BackupService(this._db, this._storage);

  /// Exports all playlists, favorites, and settings into a JSON-compatible map
  Future<String> exportBackupJson() async {
    final playlists = await _db.getAllPlaylists();
    final allFavorites = await (_db.select(_db.favoritesTable)).get();

    final exportPlaylists = <Map<String, dynamic>>[];
    for (final p in playlists) {
      final creds = await _storage.getPlaylistCredentials(p.id);
      exportPlaylists.add({
        'id': p.id,
        'name': p.name,
        'type': p.type,
        'url': p.url,
        'filePath': p.filePath,
        'serverUrl': p.serverUrl,
        'username': p.username,
        'macAddress': p.macAddress,
        'autoRefresh': p.autoRefresh,
        'channelCount': p.channelCount,
        'position': p.position,
        'credentials': creds,
      });
    }

    final exportFavorites = allFavorites.map((f) => {
      'playlistId': f.playlistId,
      'providerId': f.providerId,
      'type': f.type,
      'title': f.title,
      'posterUrl': f.posterUrl,
      'backdropUrl': f.backdropUrl,
      'position': f.position,
    }).toList();

    final tmdbKey = await _storage.getPlaylistCredentials('filimu_tmdb_api_key');
    final tmdbLang = await _storage.getPlaylistCredentials('filimu_tmdb_language');
    final tmdbCountry = await _storage.getPlaylistCredentials('filimu_tmdb_country');
    final customUa = await _storage.getPlaylistCredentials('filimu_custom_user_agent');
    final customRef = await _storage.getPlaylistCredentials('filimu_custom_referer');

    final payload = {
      'version': '1.0',
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
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Imports a backup JSON string and restores playlists, credentials, and favorites
  Future<int> importBackupJson(String jsonString) async {
    final Map<String, dynamic> data = json.decode(jsonString);
    int importedPlaylists = 0;

    // 1. Restore Playlists & Credentials
    if (data['playlists'] is List) {
      for (final p in data['playlists'] as List) {
        if (p is Map) {
          final id = p['id']?.toString();
          if (id == null) continue;

          await _db.insertPlaylist(
            PlaylistsTableCompanion(
              id: Value(id),
              name: Value(p['name']?.toString() ?? 'Restored Playlist'),
              type: Value(p['type']?.toString() ?? 'm3u_url'),
              url: Value(p['url']?.toString()),
              filePath: Value(p['filePath']?.toString()),
              serverUrl: Value(p['serverUrl']?.toString()),
              username: Value(p['username']?.toString()),
              macAddress: Value(p['macAddress']?.toString()),
              autoRefresh: Value(p['autoRefresh'] == true),
              channelCount: Value(p['channelCount'] is int ? p['channelCount'] as int : 0),
              position: Value(p['position'] is int ? p['position'] as int : 0),
            ),
          );

          final creds = p['credentials']?.toString();
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

          if (playlistId != null && providerId != null && type != null && title != null) {
            await _db.into(_db.favoritesTable).insertOnConflictUpdate(
              FavoritesTableCompanion(
                playlistId: Value(playlistId),
                providerId: Value(providerId),
                type: Value(type),
                title: Value(title),
                posterUrl: Value(f['posterUrl']?.toString()),
                backdropUrl: Value(f['backdropUrl']?.toString()),
                position: Value(f['position'] is int ? f['position'] as int : 0),
              ),
            );
          }
        }
      }
    }

    // 3. Restore Settings
    if (data['settings'] is Map) {
      final s = data['settings'] as Map;
      if (s['tmdbApiKey'] != null) {
        await _storage.savePlaylistCredentials('filimu_tmdb_api_key', s['tmdbApiKey'].toString());
      }
      if (s['tmdbLanguage'] != null) {
        await _storage.savePlaylistCredentials('filimu_tmdb_language', s['tmdbLanguage'].toString());
      }
      if (s['tmdbCountry'] != null) {
        await _storage.savePlaylistCredentials('filimu_tmdb_country', s['tmdbCountry'].toString());
      }
      if (s['customUserAgent'] != null) {
        await _storage.savePlaylistCredentials('filimu_custom_user_agent', s['customUserAgent'].toString());
      }
      if (s['customReferer'] != null) {
        await _storage.savePlaylistCredentials('filimu_custom_referer', s['customReferer'].toString());
      }
    }

    return importedPlaylists;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  return BackupService(db, storage);
});
