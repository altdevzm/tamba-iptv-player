import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/diagnostics/app_logger.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/persistence/database_provider.dart';
import 'core/security/secure_storage_service.dart';
import 'features/content_details/domain/device_form_factor.dart';
import 'features/player/streaming/streaming_manager.dart';
import 'features/remote_control/data/remote_control_server.dart';

void main() async {
  // Stage 1: Essential services & sanitized crash diagnostics
  AppLogger.markAppStart();
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    AppLogger.error('FlutterError', details.exceptionAsString(), details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('UnhandledError', 'Uncaught async exception', error, stack);
    return true;
  };

  try {
    MediaKit.ensureInitialized();
  } catch (e, st) {
    AppLogger.error('Startup', 'MediaKit initialization failed (LibVLC fallback remains available)', e, st);
  }
  StreamingManager.configureResourceCaches();

  // Stage 2: Detect native Android TV (Leanback / UI_MODE_TYPE_TELEVISION) &
  // restore saved "Force Smart TV Mode" preference before first frame.
  if (!kIsWeb && Platform.isAndroid) {
    try {
      const deviceChannel = MethodChannel('tamba_iptv/device');
      final isNativeTv =
          await deviceChannel.invokeMethod<bool>('isAndroidTv') ?? false;
      if (isNativeTv) {
        DeviceFormFactor.nativeAndroidTv = true;
        AppLogger.info('Startup', 'Detected native Android TV / Leanback device');
      }
    } catch (_) {}
  }

  try {
    final storage = SecureStorageService();
    final savedTvMode =
        await storage.getPlaylistCredentials('filimu_force_tv_mode');
    if (savedTvMode == 'true') {
      DeviceFormFactor.forceTvMode.value = true;
    }
  } catch (e) {
    AppLogger.warn('Startup', 'Could not restore TV mode preference: $e');
  }

  runApp(
    const ProviderScope(
      child: FilimuPlusApp(),
    ),
  );
}

class FilimuPlusApp extends ConsumerStatefulWidget {
  const FilimuPlusApp({super.key});

  @override
  ConsumerState<FilimuPlusApp> createState() => _FilimuPlusAppState();
}

class _FilimuPlusAppState extends ConsumerState<FilimuPlusApp> {
  Timer? _deferredServicesTimer;

  @override
  void initState() {
    super.initState();
    // Stage 3: Measure first frame & defer non-essential background services
    // (local web remote server) until after Home has rendered cleanly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.markFirstFrameReady();
      _bootstrapActivePlaylist();
      _deferredServicesTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(remoteControlServerProvider);
        }
      });
    });
  }

  Future<void> _bootstrapActivePlaylist() async {
    try {
      if (ref.read(activePlaylistIdProvider) != null) return;
      final db = ref.read(databaseProvider);
      final playlists = await db.getAllPlaylists();
      if (mounted &&
          playlists.isNotEmpty &&
          ref.read(activePlaylistIdProvider) == null) {
        ref.read(activePlaylistIdProvider.notifier).state = playlists.first.id;
      }
    } catch (e, st) {
      AppLogger.error('Startup', 'Failed to bootstrap active playlist', e, st);
    }
  }

  @override
  void dispose() {
    _deferredServicesTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Tamba IPTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
