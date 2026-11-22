import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Consistent Smart TV focus container that clearly distinguishes:
/// 1. **Focused** — prominent Tamba Blue border, blue halo glow, elevated
///    blue-tinted surface, crisp contrast, and optional slight scale.
/// 2. **Selected** — Tamba Red accent border/tint when explicitly chosen.
/// 3. **Active** — subtle elevated surface when representing the active
///    route or category.
///
/// Automatically scrolls the focused item into view so focus never disappears
/// off-screen during D-pad navigation.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isSelected;
  final bool isActive;
  final double borderRadius;
  final double scaleOnFocus;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final ValueChanged<bool>? onFocusChange;
  final bool ensureVisibleOnFocus;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.isSelected = false,
    this.isActive = false,
    this.borderRadius = 12,
    this.scaleOnFocus = 1.0,
    this.padding,
    this.backgroundColor,
    this.onFocusChange,
    this.ensureVisibleOnFocus = true,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  bool _hovered = false;

  void _handleFocusChange(bool hasFocus) {
    if (_focused != hasFocus) {
      setState(() => _focused = hasFocus);
    }
    widget.onFocusChange?.call(hasFocus);
    if (hasFocus && widget.ensureVisibleOnFocus && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.35,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    if (_focused) {
      bg = AppColors.tvFocusFill;
    } else if (widget.isSelected) {
      bg = AppColors.primary.withValues(alpha: 0.2);
    } else if (widget.isActive) {
      bg = Colors.white.withValues(alpha: 0.11);
    } else if (_hovered) {
      bg = Colors.white.withValues(alpha: 0.06);
    } else {
      bg = widget.backgroundColor ?? Colors.transparent;
    }

    final Color borderColor;
    final double borderWidth;
    if (_focused) {
      borderColor = AppColors.tvFocusBright;
      borderWidth = 2.5;
    } else if (widget.isSelected) {
      borderColor = AppColors.primary;
      borderWidth = 1.5;
    } else if (widget.isActive) {
      borderColor = Colors.white.withValues(alpha: 0.22);
      borderWidth = 1.0;
    } else if (_hovered) {
      borderColor = Colors.white.withValues(alpha: 0.16);
      borderWidth = 1.0;
    } else {
      borderColor = Colors.transparent;
      borderWidth = 1.0;
    }

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onShowHoverHighlight: (h) {
        if (_hovered != h) setState(() => _hovered = h);
      },
      actions: widget.onPressed == null
          ? const {}
          : {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onPressed?.call();
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _focused ? widget.scaleOnFocus : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: _focused
                  ? const [
                      BoxShadow(
                        color: AppColors.tvFocusGlow,
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Saves the currently focused [FocusNode] before opening a dialog or modal,
/// and restores focus to it when the modal closes so TV remote focus never
/// vanishes into the void.
class TvFocusRestorer {
  static Future<T?> runWithFocusRestore<T>(
    Future<T?> Function() action,
  ) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    try {
      return await action();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previousFocus != null && previousFocus.canRequestFocus) {
          previousFocus.requestFocus();
        }
      });
    }
  }
}
