import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/persistence/database_provider.dart';
import 'core/security/secure_storage_service.dart';
import 'features/content_details/domain/device_form_factor.dart';
import 'features/remote_control/data/remote_control_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Restore saved "Force Smart TV Mode" preference before first frame
  try {
    final storage = SecureStorageService();
    final savedTvMode =
        await storage.getPlaylistCredentials('filimu_force_tv_mode');
    if (savedTvMode == 'true') {
      DeviceFormFactor.forceTvMode.value = true;
    }
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: FilimuPlusApp(),
    ),
  );
}

class FilimuPlusApp extends ConsumerWidget {
  const FilimuPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start local web remote control server
    ref.watch(remoteControlServerProvider);

    // Auto-bootstrap active playlist on startup
    final db = ref.watch(databaseProvider);
    final activeId = ref.watch(activePlaylistIdProvider);
    if (activeId == null) {
      db.getAllPlaylists().then((playlists) {
        if (playlists.isNotEmpty && ref.read(activePlaylistIdProvider) == null) {
          ref.read(activePlaylistIdProvider.notifier).state = playlists.first.id;
        }
      });
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Tamba IPTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
