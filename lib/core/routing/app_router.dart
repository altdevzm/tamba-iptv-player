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
import '../../shared/widgets/tv_text_field.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(
            currentRoute: state.uri.toString(),
            navigationShell: navigationShell,
            child: navigationShell,
          );
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeView(),
              ),
              GoRoute(
                path: '/recent',
                builder: (context, state) => const HomeView(),
              ),
              GoRoute(
                path: '/watch-later',
                builder: (context, state) => const HomeView(),
              ),
            ],
          ),
          // Branch 1: Live TV
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                builder: (context, state) => const LiveTvView(),
              ),
              GoRoute(
                path: '/epg',
                builder: (context, state) => const EpgGridView(),
              ),
            ],
          ),
          // Branch 2: Movies
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/movies',
                builder: (context, state) => const MoviesView(),
              ),
              GoRoute(
                path: '/popular',
                builder: (context, state) => const MoviesView(),
              ),
            ],
          ),
          // Branch 3: Series
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/series',
                builder: (context, state) => const SeriesView(),
              ),
            ],
          ),
          // Branch 4: My List
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesView(),
              ),
            ],
          ),
          // Branch 5: Utility routes (Search, Settings, Playlists, Downloads, Disclaimer)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const GlobalSearchView(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsView(),
              ),
              GoRoute(
                path: '/playlists',
                builder: (context, state) => const PlaylistsView(),
              ),
              GoRoute(
                path: '/downloads',
                builder: (context, state) => const DownloadsView(),
              ),
              GoRoute(
                path: '/disclaimer',
                builder: (context, state) => const DisclaimerView(),
              ),
            ],
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
  final StatefulNavigationShell? navigationShell;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentRoute,
    this.navigationShell,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(effectivePlaylistIdProvider);
    final isFullscreen =
        ref.watch(playerControllerProvider.select((s) => s.isFullscreen));

    if (isFullscreen) {
      return const FullscreenPlayerView();
    }

    final isOnHome = currentRoute == '/home' || currentRoute == '/';

    return PopScope(
      canPop: isOnHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell != null) {
          navigationShell!.goBranch(0);
        } else {
          context.go('/home');
        }
      },
      child: Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Never hijack keys while any text input or on-screen keyboard is active
        final primary = FocusManager.instance.primaryFocus;
        final focusContext = primary?.context;
        final isEditingText = TvTextField.isAnyEditing ||
            (focusContext != null &&
                (focusContext.widget is EditableText ||
                    focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                        null ||
                    focusContext.findAncestorWidgetOfExactType<TextField>() !=
                        null));
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
          // Only toggle playback on space if a player item is active and no
          // button/card is handling ActivateIntent via space.
          final playerState = ref.read(playerControllerProvider);
          if (playerState.currentItem != null && primary == node) {
            ref.read(playerControllerProvider.notifier).togglePlayPause();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.keyF) {
          final ctrl = ref.read(playerControllerProvider.notifier);
          final playerState = ref.read(playerControllerProvider);
          if (playerState.isFullscreen) {
            ctrl.closePlayer();
            return KeyEventResult.handled;
          } else if (playerState.currentItem != null) {
            ctrl.openFullscreen();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          final ctrl = ref.read(playerControllerProvider.notifier);
          final playerState = ref.read(playerControllerProvider);
          if (playerState.isFullscreen) {
            ctrl.closePlayer();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          PlatformNavigationShell(
            currentRoute: currentRoute,
            navigationShell: navigationShell,
            child: child,
          ),
          const FloatingMiniPlayerPill(),
        ],
      ),
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
