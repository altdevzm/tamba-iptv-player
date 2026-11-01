import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SecureStorageService {
  File? _file;
  Map<String, String>? _cache;

  static const _pinKey = 'filimu_parental_pin_hash';
  static const _playlistCredsPrefix = 'filimu_playlist_creds_';

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File(p.join(dir.path, '.filimu_vault.dat'));
    return _file!;
  }

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final raw = _decrypt(content);
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cache = decoded.map((k, v) => MapEntry(k, v.toString()));
        return _cache!;
      }
    } catch (_) {}
    _cache = <String, String>{};
    return _cache!;
  }

  Future<void> _save() async {
    final file = await _getFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final raw = jsonEncode(_cache ?? {});
    await file.writeAsString(_encrypt(raw));
  }

  String _encrypt(String input) {
    final bytes = utf8.encode(input);
    const key = [0x50, 0x4C, 0x55, 0x53, 0x46, 0x49, 0x4C, 0x49, 0x4D, 0x55];
    final encoded = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64Url.encode(encoded);
  }

  String _decrypt(String input) {
    final bytes = base64Url.decode(input);
    const key = [0x50, 0x4C, 0x55, 0x53, 0x46, 0x49, 0x4C, 0x49, 0x4D, 0x55];
    final decoded = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return utf8.decode(decoded);
  }

  // --- Parental Lock PIN ---
  Future<void> setParentalPin(String pin) async {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    final data = await _load();
    data[_pinKey] = digest.toString();
    await _save();
  }

  Future<bool> verifyParentalPin(String pin) async {
    final data = await _load();
    final savedHash = data[_pinKey];
    if (savedHash == null) return false;
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString() == savedHash;
  }

  Future<bool> hasParentalPin() async {
    final data = await _load();
    final savedHash = data[_pinKey];
    return savedHash != null && savedHash.isNotEmpty;
  }

  Future<void> clearParentalPin() async {
    final data = await _load();
    data.remove(_pinKey);
    await _save();
  }

  // --- Encrypted Playlist Credentials ---
  Future<void> savePlaylistCredentials(String playlistId, String password) async {
    final data = await _load();
    data['$_playlistCredsPrefix$playlistId'] = password;
    await _save();
  }

  Future<String?> getPlaylistCredentials(String playlistId) async {
    final data = await _load();
    return data['$_playlistCredsPrefix$playlistId'];
  }

  Future<void> deletePlaylistCredentials(String playlistId) async {
    final data = await _load();
    data.remove('$_playlistCredsPrefix$playlistId');
    await _save();
  }
}
