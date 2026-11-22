import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../features/content_details/domain/device_form_factor.dart';
import 'tv_on_screen_keyboard.dart';

/// Smart TV-ready [TextField] that ensures reliable text input across:
/// 1. Native Android TV / Google TV IME (`TextInput.show` on OK/SELECT/tap).
/// 2. Physical, Bluetooth, and USB keyboards (zero key swallowing).
/// 3. Built-in D-pad [TvOnScreenKeyboard] fallback when native IME is
///    unavailable or inconvenient on a TV remote.
/// 4. Predictable D-pad UP/DOWN escape from single-line fields and clear
///    Tamba Blue focus highlight + auto-scroll into view.
class TvTextField extends StatefulWidget {
  /// Tracks whether ANY [TvTextField] currently holds focus so global shortcut
  /// handlers never hijack character/space/F keys while typing.
  static int _activeEditingCount = 0;
  static bool get isAnyEditing => _activeEditingCount > 0;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final bool autocorrect;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;
  final double borderRadius;

  const TvTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.autocorrect = false,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.decoration,
    this.borderRadius = 12,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  FocusNode? _internalFocusNode;
  bool _hasFocus = false;
  bool _countedActive = false;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChanged);
    _effectiveFocusNode.onKeyEvent = _handleKeyEvent;
  }

  @override
  void didUpdateWidget(covariant TvTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _effectiveFocusNode.addListener(_onFocusChanged);
      _effectiveFocusNode.onKeyEvent = _handleKeyEvent;
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChanged);
    if (_countedActive) {
      TvTextField._activeEditingCount =
          (TvTextField._activeEditingCount - 1).clamp(0, 999);
      _countedActive = false;
    }
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final focused = _effectiveFocusNode.hasFocus;
    if (focused && !_countedActive) {
      TvTextField._activeEditingCount++;
      _countedActive = true;
    } else if (!focused && _countedActive) {
      TvTextField._activeEditingCount =
          (TvTextField._activeEditingCount - 1).clamp(0, 999);
      _countedActive = false;
    }
    if (mounted && _hasFocus != focused) {
      setState(() => _hasFocus = focused);
    }
    if (focused && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  Future<void> _requestNativeKeyboard() async {
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } catch (_) {}
  }

  Future<void> _openTvKeyboardFallback() async {
    if (!mounted) return;
    await TvOnScreenKeyboard.show(
      context,
      controller: widget.controller,
      title: widget.labelText ?? widget.hintText ?? 'Enter Text',
      hintText: widget.hintText,
      obscureText: widget.obscureText,
      isUrl: widget.keyboardType == TextInputType.url,
      isNumeric: widget.keyboardType == TextInputType.number,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Allow D-pad UP / DOWN to escape a single-line text field predictably
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!node.focusInDirection(TraversalDirection.down)) {
        node.nextFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!node.focusInDirection(TraversalDirection.up)) {
        node.previousFocus();
      }
      return KeyEventResult.handled;
    }

    // D-pad OK / SELECT on a focused text field: summon native Android TV IME
    // (and if native IME is unavailable on the box, the adjacent TV keyboard
    // button is one D-pad RIGHT press away).
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _requestNativeKeyboard();
      return KeyEventResult.handled;
    }

    // Physical / Bluetooth / USB keyboard keys pass straight through to EditableText
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceFormFactor.isTv(context);

    final baseDecoration = widget.decoration ??
        InputDecoration(
          labelText: widget.labelText,
          labelStyle: TextStyle(
            color: _hasFocus
                ? AppColors.tvFocusBright
                : Colors.white.withValues(alpha: 0.65),
            fontSize: 12.5,
            fontWeight: _hasFocus ? FontWeight.w700 : FontWeight.w500,
          ),
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 13.5,
          ),
          prefixIcon: widget.prefixIcon,
          filled: true,
          fillColor: _hasFocus
              ? AppColors.tvFocus.withValues(alpha: 0.12)
              : const Color(0xFF1E1E25),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    final tvKeyboardButton = IconButton(
      tooltip: 'Open Remote Keyboard',
      onPressed: widget.enabled ? _openTvKeyboardFallback : null,
      icon: Icon(
        Icons.keyboard_rounded,
        color: _hasFocus ? AppColors.tvFocusBright : Colors.white60,
        size: 20,
      ),
    );

    Widget? resolvedSuffix = widget.suffixIcon;
    if (isTv) {
      resolvedSuffix = resolvedSuffix == null
          ? tvKeyboardButton
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [resolvedSuffix, tvKeyboardButton],
            );
    }

    final effectiveDecoration = baseDecoration.copyWith(
      suffixIcon: resolvedSuffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: const BorderSide(
          color: AppColors.tvFocusBright,
          width: 2.5,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: _hasFocus
            ? const [
                BoxShadow(
                  color: AppColors.tvFocusGlow,
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        maxLength: widget.maxLength,
        textAlign: widget.textAlign,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction ??
            (widget.onSubmitted != null
                ? TextInputAction.search
                : TextInputAction.next),
        style: widget.style ?? const TextStyle(color: Colors.white, fontSize: 14),
        onTap: _requestNativeKeyboard,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: effectiveDecoration,
      ),
    );
  }
}
