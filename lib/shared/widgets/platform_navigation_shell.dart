import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/content_details/domain/device_form_factor.dart';
import 'flixor_top_nav_bar.dart';
import 'mobile_bottom_nav.dart';
import 'platform_navigation_sidebar.dart';
import 'top_header_bar.dart';
import 'tv_text_field.dart';

class PlatformNavigationShell extends StatefulWidget {
  final String currentRoute;
  final StatefulNavigationShell? navigationShell;
  final Widget child;

  const PlatformNavigationShell({
    super.key,
    required this.currentRoute,
    this.navigationShell,
    required this.child,
  });

  @override
  State<PlatformNavigationShell> createState() =>
      _PlatformNavigationShellState();
}

class _PlatformNavigationShellState extends State<PlatformNavigationShell> {
  final FocusScopeNode _navFocusScope =
      FocusScopeNode(debugLabel: 'PlatformNavScope');
  final FocusScopeNode _contentFocusScope =
      FocusScopeNode(debugLabel: 'PlatformContentScope');

  @override
  void dispose() {
    _navFocusScope.dispose();
    _contentFocusScope.dispose();
    super.dispose();
  }

  void _focusScopeTarget(FocusScopeNode scope) {
    final prev = scope.focusedChild;
    if (prev != null && prev.canRequestFocus && !prev.skipTraversal) {
      prev.requestFocus();
      return;
    }
    final first = scope.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal)
        .firstOrNull;
    if (first != null) {
      first.requestFocus();
    } else {
      scope.requestFocus();
    }
  }

  void _focusNavMenu() => _focusScopeTarget(_navFocusScope);

  void _focusContent() => _focusScopeTarget(_contentFocusScope);

  KeyEventResult _handleContentKeyEvent(
    FocusNode node,
    KeyEvent event, {
    required bool isSidebarLayout,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (TvTextField.isAnyEditing) return KeyEventResult.ignored;

    final primary = FocusManager.instance.primaryFocus;
    final key = event.logicalKey;

    if (isSidebarLayout) {
      // At the left edge of any row/grid, D-pad LEFT jumps straight into Sidebar
      if (key == LogicalKeyboardKey.arrowLeft) {
        final moved = primary?.focusInDirection(TraversalDirection.left) ?? false;
        if (!moved) {
          _focusNavMenu();
        }
        return KeyEventResult.handled;
      }
    } else {
      // At the top edge of content, D-pad UP jumps straight into Top Nav Bar
      if (key == LogicalKeyboardKey.arrowUp) {
        final moved = primary?.focusInDirection(TraversalDirection.up) ?? false;
        if (!moved) {
          _focusNavMenu();
        }
        return KeyEventResult.handled;
      }
    }

    // Menu key (or BACK while already on Home) brings focus directly to Nav Menu
    final isOnHome =
        widget.currentRoute == '/home' || widget.currentRoute == '/';
    if (key == LogicalKeyboardKey.contextMenu ||
        (isOnHome &&
            (key == LogicalKeyboardKey.goBack ||
                key == LogicalKeyboardKey.escape))) {
      _focusNavMenu();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleNavKeyEvent(
    FocusNode node,
    KeyEvent event, {
    required bool isSidebarLayout,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (isSidebarLayout && key == LogicalKeyboardKey.arrowRight) {
      _focusContent();
      return KeyEventResult.handled;
    }
    if (!isSidebarLayout && key == LogicalKeyboardKey.arrowDown) {
      _focusContent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceFormFactor.forceTvMode,
      builder: (context, _, __) {
        final isTv = DeviceFormFactor.isTv(context);
        final isDesktop = DeviceFormFactor.isDesktop(context);
        final width = MediaQuery.sizeOf(context).width;

        if (isTv || isDesktop) {
          final compactSidebar = isTv || width < 1000;
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                Focus(
                  skipTraversal: true,
                  onKeyEvent: (n, e) =>
                      _handleNavKeyEvent(n, e, isSidebarLayout: true),
                  child: FocusScope(
                    node: _navFocusScope,
                    child: FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: PlatformNavigationSidebar(
                        currentRoute: widget.currentRoute,
                        isTv: isTv,
                        compact: compactSidebar,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Focus(
                    skipTraversal: true,
                    onKeyEvent: (n, e) =>
                        _handleContentKeyEvent(n, e, isSidebarLayout: true),
                    child: FocusScope(
                      node: _contentFocusScope,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: Column(
                          children: [
                            if (isDesktop)
                              TopHeaderBar(
                                onProfileTap: () => context.go('/settings'),
                              ),
                            Expanded(child: widget.child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final showBottomNavigation =
            width < DeviceFormFactor.mobileNavigationBreakpoint;

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: showBottomNavigation
              ? FilimuMobileBottomNav(
                  currentRoute: widget.currentRoute,
                  navigationShell: widget.navigationShell,
                )
              : null,
          body: Column(
            children: [
              Focus(
                skipTraversal: true,
                onKeyEvent: (n, e) =>
                    _handleNavKeyEvent(n, e, isSidebarLayout: false),
                child: FocusScope(
                  node: _navFocusScope,
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: FlixorTopNavBar(
                      currentRoute: widget.currentRoute,
                      navigationShell: widget.navigationShell,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Focus(
                  skipTraversal: true,
                  onKeyEvent: (n, e) =>
                      _handleContentKeyEvent(n, e, isSidebarLayout: false),
                  child: FocusScope(
                    node: _contentFocusScope,
                    child: FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
