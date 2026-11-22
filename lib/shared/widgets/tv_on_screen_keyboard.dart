import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import 'tv_focusable.dart';

/// Full D-pad remote-controlled on-screen keyboard fallback for Smart TVs
/// (Android TV, Google TV, AOSP TV boxes) when native IME is unavailable or
/// inconvenient with a TV remote.
///
/// Supports:
/// - Full QWERTY + Shift + Numbers/Symbols layout
/// - Dedicated numeric pad for PIN / numeric fields
/// - IPTV URL quick tokens (`http://`, `https://`, `.com`, `.m3u`, `:8080`, `/`, `:`, `.`)
/// - Direct physical/Bluetooth/USB keyboard pass-through while open
/// - Automatic focus restoration on close
class TvOnScreenKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  final String? hintText;
  final bool obscureText;
  final bool isUrl;
  final bool isNumeric;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const TvOnScreenKeyboard({
    super.key,
    required this.controller,
    required this.title,
    this.hintText,
    this.obscureText = false,
    this.isUrl = false,
    this.isNumeric = false,
    this.onChanged,
    this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required String title,
    String? hintText,
    bool obscureText = false,
    bool isUrl = false,
    bool isNumeric = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TvFocusRestorer.runWithFocusRestore<void>(() {
      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.78),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: TvOnScreenKeyboard(
            controller: controller,
            title: title,
            hintText: hintText,
            obscureText: obscureText,
            isUrl: isUrl,
            isNumeric: isNumeric,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      );
    });
  }

  @override
  State<TvOnScreenKeyboard> createState() => _TvOnScreenKeyboardState();
}

class _TvOnScreenKeyboardState extends State<TvOnScreenKeyboard> {
  bool _shifted = false;
  bool _symbols = false;

  static const _alphaRows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '@'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '-', '_'],
  ];

  static const _symbolRows = <List<String>>[
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
    [':', '/', '?', '=', '&', '_', '-', '+', '.', ','],
    ['~', '[', ']', '{', '}', '|', '\\', ';', '\'', '"'],
  ];

  static const _urlQuickTokens = <String>[
    'http://',
    'https://',
    '.com',
    '.m3u',
    '.m3u8',
    ':8080',
    '/get.php?',
    '/',
  ];

  static const _numRows = <List<String>>[
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['CLEAR', '0', '⌫'],
  ];

  void _insertText(String text) {
    final current = widget.controller.text;
    final next = '$current$text';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    widget.onChanged?.call(next);
    if (_shifted && text.length == 1) {
      setState(() => _shifted = false);
    } else {
      setState(() {});
    }
  }

  void _backspace() {
    final current = widget.controller.text;
    if (current.isEmpty) return;
    final next = current.substring(0, current.length - 1);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    widget.onChanged?.call(next);
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    setState(() {});
  }

  void _submit() {
    final value = widget.controller.text;
    Navigator.of(context).pop();
    widget.onSubmitted?.call(value);
  }

  KeyEventResult _handleHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    // Allow physical / Bluetooth / USB keyboard typing directly while open
    final ch = event.character;
    if (ch != null &&
        ch.isNotEmpty &&
        ch.codeUnitAt(0) >= 32 &&
        ch.codeUnitAt(0) != 127 &&
        event.logicalKey != LogicalKeyboardKey.space) {
      _insertText(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rawText = widget.controller.text;
    final displayText =
        widget.obscureText ? '•' * rawText.length : rawText;

    return Focus(
      skipTraversal: true,
      onKeyEvent: _handleHardwareKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.isNumeric ? 380 : 760,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF14151D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.tvFocus.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      color: AppColors.tvFocusBright,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TvFocusable(
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Input Preview
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0D12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.tvFocusBright,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    displayText.isEmpty
                        ? (widget.hintText ?? 'Use remote or keyboard to type…')
                        : '$displayText│',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: displayText.isEmpty
                          ? Colors.white38
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: widget.obscureText ? 3 : 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (widget.isNumeric)
                  _buildNumericPad()
                else ...[
                  if (widget.isUrl) ...[
                    _buildUrlQuickRow(),
                    const SizedBox(height: 10),
                  ],
                  _buildQwertyPad(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlQuickRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _urlQuickTokens.map((token) {
        return TvFocusable(
          borderRadius: 8,
          scaleOnFocus: 1.05,
          backgroundColor: AppColors.tvFocus.withValues(alpha: 0.14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          onPressed: () => _insertText(token),
          child: Text(
            token,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQwertyPad() {
    final rows = _symbols ? _symbolRows : _alphaRows;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < rows.length; r++) ...[
            Row(
              children: [
                for (int c = 0; c < rows[r].length; c++) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _buildKeyButton(
                        label: _shifted && !_symbols
                            ? rows[r][c].toUpperCase()
                            : rows[r][c],
                        autofocus: r == 1 && c == 0,
                        onPressed: () => _insertText(
                          _shifted && !_symbols
                              ? rows[r][c].toUpperCase()
                              : rows[r][c],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: _shifted ? 'SHIFT ✓' : 'SHIFT',
                    isSelected: _shifted,
                    onPressed: () => setState(() => _shifted = !_shifted),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: _symbols ? 'ABC' : '#+=',
                    isSelected: _symbols,
                    onPressed: () => setState(() => _symbols = !_symbols),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: 'SPACE',
                    onPressed: () => _insertText(' '),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: '⌫',
                    onPressed: _backspace,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: 'CLEAR',
                    onPressed: _clear,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: _buildKeyButton(
                    label: 'DONE',
                    isPrimary: true,
                    onPressed: _submit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumericPad() {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < _numRows.length; r++)
            Row(
              children: [
                for (int c = 0; c < _numRows[r].length; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _buildKeyButton(
                        label: _numRows[r][c],
                        autofocus: r == 0 && c == 0,
                        onPressed: () {
                          final token = _numRows[r][c];
                          if (token == 'CLEAR') {
                            _clear();
                          } else if (token == '⌫') {
                            _backspace();
                          } else {
                            _insertText(token);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildKeyButton(
              label: 'DONE',
              isPrimary: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton({
    required String label,
    required VoidCallback onPressed,
    bool autofocus = false,
    bool isSelected = false,
    bool isPrimary = false,
  }) {
    return TvFocusable(
      autofocus: autofocus,
      isSelected: isSelected || isPrimary,
      borderRadius: 10,
      scaleOnFocus: 1.06,
      backgroundColor: isPrimary
          ? AppColors.primary
          : Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      onPressed: onPressed,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: label.length > 3 ? 12 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
