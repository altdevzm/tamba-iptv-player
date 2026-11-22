import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'tv_focusable.dart';

class PlatformNavigationSidebar extends StatefulWidget {
  final String currentRoute;
  final bool isTv;
  final bool compact;

  const PlatformNavigationSidebar({
    super.key,
    required this.currentRoute,
    required this.isTv,
    required this.compact,
  });

  @override
  State<PlatformNavigationSidebar> createState() =>
      _PlatformNavigationSidebarState();
}

class _PlatformNavigationSidebarState extends State<PlatformNavigationSidebar> {
  late bool _expanded = !widget.compact;

  @override
  void didUpdateWidget(covariant PlatformNavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact != widget.compact) {
      _expanded = !widget.compact;
    }
  }

  @override
  Widget build(BuildContext context) {
    // On Smart TVs, always show labels on a sleek 220px sidebar so Home,
    // Live TV, Movies, Series, Search, and Settings are always visible.
    final showLabels = widget.isTv || !widget.compact || _expanded;

    return Focus(
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (!widget.isTv && widget.compact && mounted) {
          setState(() => _expanded = hasFocus);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: showLabels ? (widget.isTv ? 220 : 238) : 76,
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.97),
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: showLabels ? 20 : 12),
              child: Row(
                children: [
                  if (showLabels)
                    const Expanded(
                      child: _Brand(),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                    ),
                  if (widget.compact && !widget.isTv)
                    IconButton(
                      tooltip: showLabels ? 'Collapse navigation' : 'Expand navigation',
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        showLabels
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: showLabels ? 14 : 10),
            child: showLabels
                ? _SearchField(currentRoute: widget.currentRoute)
                : IconButton(
                    tooltip: 'Search',
                    onPressed: () => context.go('/search'),
                    icon: const Icon(Icons.search_rounded),
                    color: widget.currentRoute.startsWith('/search')
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FocusTraversalGroup(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: showLabels ? 10 : 8),
                children: [
                  if (showLabels) const _SectionHeader('Browse'),
                  _Destination(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    route: '/home',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                    autofocus: widget.isTv,
                  ),
                  _Destination(
                    icon: Icons.live_tv_rounded,
                    label: 'Live TV',
                    route: '/live',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.calendar_view_week_rounded,
                    label: 'TV Guide',
                    route: '/epg',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.tv_rounded,
                    label: 'TV Shows',
                    route: '/series',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.movie_creation_outlined,
                    label: 'Movies',
                    route: '/movies',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.bookmark_border_rounded,
                    label: 'My List',
                    route: '/favorites',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.download_rounded,
                    label: 'Downloads',
                    route: '/downloads',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  if (showLabels) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader('Library'),
                  ] else
                    const SizedBox(height: 12),
                  _Destination(
                    icon: Icons.playlist_play_rounded,
                    label: 'Playlists & Providers',
                    route: '/playlists',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                  _Destination(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    route: '/settings',
                    currentRoute: widget.currentRoute,
                    compact: !showLabels,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const ClipRect(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'TAMBA IPTV',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String currentRoute;

  const _SearchField({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute.startsWith('/search');

    return TvFocusable(
      isActive: isActive,
      borderRadius: 10,
      backgroundColor: Colors.white.withValues(alpha: 0.07),
      onPressed: () => context.go('/search'),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              size: 19,
              color: isActive ? AppColors.primary : Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search all...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Destination extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final bool compact;
  final bool autofocus;

  const _Destination({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.compact,
    this.autofocus = false,
  });

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active =>
      widget.currentRoute == widget.route ||
      widget.currentRoute.startsWith('${widget.route}/') ||
      (widget.route == '/home' && widget.currentRoute == '/');

  void _navigate() {
    if (!_active) context.go(widget.route);
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _active || _focused || _hovered;
    return Tooltip(
      message: widget.compact ? widget.label : '',
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onFocusChange: (value) {
          setState(() => _focused = value);
          if (value && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.35,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        },
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _navigate();
              return null;
            },
          ),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigate,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              height: 46,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding:
                  EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 12),
              decoration: BoxDecoration(
                // Clear distinction: Focused = Tamba Blue, Active = Neutral + Red bar
                color: _focused
                    ? AppColors.tvFocusFill
                    : _active
                        ? Colors.white.withValues(alpha: 0.12)
                        : _hovered
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focused
                      ? AppColors.tvFocusBright
                      : (_active
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.transparent),
                  width: _focused ? 2.5 : 1.0,
                ),
                boxShadow: _focused
                    ? const [
                        BoxShadow(
                          color: AppColors.tvFocusGlow,
                          blurRadius: 14,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: widget.compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (_active && !widget.compact) ...[
                    Container(
                      width: 3.5,
                      height: 20,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  Icon(
                    widget.icon,
                    size: 20,
                    color: _focused
                        ? Colors.white
                        : (_active ? AppColors.primary : AppColors.textSecondary),
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlighted
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13.5,
                          fontWeight: _focused
                              ? FontWeight.w700
                              : (_active ? FontWeight.w600 : FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
