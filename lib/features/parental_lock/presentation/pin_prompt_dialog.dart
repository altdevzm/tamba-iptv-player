import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/widgets/glass_container.dart';

class PinPromptDialog extends ConsumerStatefulWidget {
  final String title;

  const PinPromptDialog({
    super.key,
    this.title = 'Parental Lock',
  });

  static Future<bool> prompt(BuildContext context, {String title = 'Parental Lock'}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PinPromptDialog(title: title),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends ConsumerState<PinPromptDialog> {
  final _pinController = TextEditingController();
  bool _isSettingNewPin = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  Future<void> _checkExistingPin() async {
    final secureStorage = ref.read(secureStorageProvider);
    final hasPin = await secureStorage.hasParentalPin();
    setState(() {
      _isSettingNewPin = !hasPin;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        width: 360,
        padding: const EdgeInsets.all(28),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              _isSettingNewPin ? 'Set Parental PIN' : widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSettingNewPin
                  ? 'Enter a 4-digit PIN to restrict sensitive categories'
                  : 'Enter your 4-digit PIN to access this content',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),

            // PIN Input Field
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 16,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_isSettingNewPin ? 'Set PIN' : 'Unlock'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'Please enter a 4-digit PIN');
      return;
    }

    final secureStorage = ref.read(secureStorageProvider);

    if (_isSettingNewPin) {
      await secureStorage.setParentalPin(pin);
      if (mounted) Navigator.pop(context, true);
    } else {
      final valid = await secureStorage.verifyParentalPin(pin);
      if (valid) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'Incorrect PIN. Please try again.';
          _pinController.clear();
        });
      }
    }
  }
}
