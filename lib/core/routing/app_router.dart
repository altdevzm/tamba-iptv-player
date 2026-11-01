import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_view.dart';
import '../../features/live_tv/presentation/live_tv_view.dart';
import '../../features/movies/presentation/movies_view.dart';
import '../../features/series/presentation/series_view.dart';
import '../../features/playlists/presentation/playlists_view.dart';
import '../../features/favorites/presentation/favorites_view.dart';
import '../../features/downloads/presentation/downloads_view.dart';
import '../../features/settings/presentation/settings_view.dart';
import '../../features/settings/presentation/disclaimer_view.dart';
import '../../features/search/presentation/global_search_view.dart';
import '../../features/epg/presentation/epg_grid_view.dart';
import '../../features/player/data/player_controller.dart';
import '../../features/player/presentation/fullscreen_player_view.dart';
import '../../shared/widgets/floating_mini_player_pill.dart';
import '../../shared/widgets/platform_navigation_shell.dart';
import '../../features/movies/presentation/movie_detail_page.dart';
import '../../features/series/presentation/series_detail_page.dart';
import '../../features/content_details/domain/device_form_factor.dart';
import '../../features/content_details/presentation/tv/tv_movie_details_page.dart';
import '../../features/content_details/presentation/tv/tv_series_details_page.dart';
import '../../shared/models/media_item.dart';
import '../persistence/app_database.dart';
import '../persistence/database_provider.dart';
import '../theme/app_colors.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentRoute: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeView(),
          ),
          GoRoute(
            path: '/popular',
            builder: (context, state) => const MoviesView(),
          ),
          GoRoute(
            path: '/live',
            builder: (context, state) => const LiveTvView(),
          ),
          GoRoute(
            path: '/series',
            builder: (context, state) => const SeriesView(),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => const MoviesView(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesView(),
          ),
          GoRoute(
            path: '/playlists',
            builder: (context, state) => const PlaylistsView(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsView(),
          ),
          GoRoute(
            path: '/disclaimer',
            builder: (context, state) => const DisclaimerView(),
          ),
          GoRoute(
            path: '/recent',
            builder: (context, state) => const HomeView(),
          ),
          GoRoute(
            path: '/watch-later',
            builder: (context, state) => const HomeView(),
          ),
          GoRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsView(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const GlobalSearchView(),
          ),
          GoRoute(
            path: '/epg',
            builder: (context, state) => const EpgGridView(),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullscreenPlayerView(),
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (context, state) {
          final isTv = DeviceFormFactor.isTv(context);
          final extra = state.extra;
          if (extra is ContentItemsTableData) {
            return isTv
                ? TvMovieDetailsPage(movie: extra)
                : MovieDetailPage(movie: extra);
          } else if (extra is MediaItem) {
            final content = extra.toContentItem();
            return isTv
                ? TvMovieDetailsPage(movie: content)
                : MovieDetailPage(movie: content);
          }
          final idParam = state.pathParameters['id'] ?? '';
          return MovieDetailRouteLoader(idParam: idParam);
        },
      ),
      GoRoute(
        path: '/series/:id',
        builder: (context, state) {
          final isTv = DeviceFormFactor.isTv(context);
          final extra = state.extra;
          if (extra is ContentItemsTableData) {
            return isTv
                ? TvSeriesDetailPage(series: extra)
                : SeriesDetailPage(series: extra);
          } else if (extra is MediaItem) {
            final content = extra.toContentItem();
            return isTv
                ? TvSeriesDetailPage(series: content)
                : SeriesDetailPage(series: content);
          }
          final idParam = state.pathParameters['id'] ?? '';
          return SeriesDetailRouteLoader(idParam: idParam);
        },
      ),
    ],
  );
});

class AppShell extends ConsumerWidget {
  final String currentRoute;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(effectivePlaylistIdProvider);
    final playerState = ref.watch(playerControllerProvider);

    if (playerState.isFullscreen) {
      return const FullscreenPlayerView();
    }

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // The text field's focus node may be attached to an internal Focus widget.
        final primary = FocusManager.instance.primaryFocus;
        final focusContext = primary?.context;
        final isEditingText = focusContext != null &&
            (focusContext.widget is EditableText ||
                focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                    null);
        if (isEditingText) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed)) {
          context.go('/search');
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.space) {
          ref.read(playerControllerProvider.notifier).togglePlayPause();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyF) {
          final ctrl = ref.read(playerControllerProvider.notifier);
          if (playerState.isFullscreen) {
            ctrl.closePlayer();
          } else if (playerState.currentItem != null) {
            ctrl.openFullscreen();
          }
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          final ctrl = ref.read(playerControllerProvider.notifier);
          if (playerState.isFullscreen) {
            ctrl.closePlayer();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          PlatformNavigationShell(
            currentRoute: currentRoute,
            child: child,
          ),
          const FloatingMiniPlayerPill(),
        ],
      ),
    );
  }
}

class MovieDetailRouteLoader extends ConsumerWidget {
  final String idParam;
  const MovieDetailRouteLoader({super.key, required this.idParam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final intId = int.tryParse(idParam);
    final future = intId != null
        ? (db.select(db.contentItemsTable)..where((t) => t.id.equals(intId)))
            .getSingleOrNull()
        : (db.select(db.contentItemsTable)
              ..where((t) => t.providerId.equals(idParam)))
            .getSingleOrNull();

    return FutureBuilder<ContentItemsTableData?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0F),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: const BackButton(color: Colors.white),
            ),
            body: const Center(
              child: Text(
                'Movie not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        return DeviceFormFactor.isTv(context)
            ? TvMovieDetailsPage(movie: item)
            : MovieDetailPage(movie: item);
      },
    );
  }
}

class SeriesDetailRouteLoader extends ConsumerWidget {
  final String idParam;
  const SeriesDetailRouteLoader({super.key, required this.idParam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final intId = int.tryParse(idParam);
    final future = intId != null
        ? (db.select(db.contentItemsTable)..where((t) => t.id.equals(intId)))
            .getSingleOrNull()
        : (db.select(db.contentItemsTable)
              ..where((t) => t.providerId.equals(idParam)))
            .getSingleOrNull();

    return FutureBuilder<ContentItemsTableData?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0F),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: const BackButton(color: Colors.white),
            ),
            body: const Center(
              child: Text(
                'Series not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        return DeviceFormFactor.isTv(context)
            ? TvSeriesDetailPage(series: item)
            : SeriesDetailPage(series: item);
      },
    );
  }
}
