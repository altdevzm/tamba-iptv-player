import 'package:dio/dio.dart';
import '../security/secure_storage_service.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService? storage;

  ApiClient({Dio? customDio, this.storage})
      : dio = customDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
                sendTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent': 'IPTVSmartersPro/1.0.0 (Linux; Android) VLC/3.0.18',
                  'Accept': '*/*',
                },
                followRedirects: true,
                maxRedirects: 5,
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (storage != null) {
            try {
              final customUa = await storage!.getPlaylistCredentials('filimu_custom_user_agent');
              if (customUa != null && customUa.trim().isNotEmpty) {
                options.headers['User-Agent'] = customUa.trim();
              }
              final customRef = await storage!.getPlaylistCredentials('filimu_custom_referer');
              if (customRef != null && customRef.trim().isNotEmpty) {
                options.headers['Referer'] = customRef.trim();
              }
            } catch (_) {}
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Redact passwords from logged request URIs
          final safeUri = _sanitizeUri(error.requestOptions.uri);
          // ignore: avoid_print
          print('Network error on: $safeUri [${error.type}] - ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  static String _sanitizeUri(Uri uri) {
    var query = uri.queryParameters;
    if (query.containsKey('password')) {
      final safeParams = Map<String, String>.from(query);
      safeParams['password'] = '******';
      return uri.replace(queryParameters: safeParams).toString();
    }
    return uri.toString();
  }
}

