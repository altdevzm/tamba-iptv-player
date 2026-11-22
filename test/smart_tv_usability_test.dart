import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:filimu_plus/core/theme/app_colors.dart';
import 'package:filimu_plus/core/theme/app_theme.dart';
import 'package:filimu_plus/features/content_details/domain/device_form_factor.dart';
import 'package:filimu_plus/shared/widgets/platform_navigation_shell.dart';
import 'package:filimu_plus/shared/widgets/tv_focusable.dart';
import 'package:filimu_plus/shared/widgets/tv_on_screen_keyboard.dart';
import 'package:filimu_plus/shared/widgets/tv_text_field.dart';

void main() {
  tearDown(() {
    DeviceFormFactor.forceTvMode.value = false;
  });

  group('Priority 1 — Smart TV Keyboard & Text Input', () {
    testWidgets('TvTextField accepts text, tracks editing state, and escapes on D-pad DOWN',
        (tester) async {
      DeviceFormFactor.forceTvMode.value = true;
      final ctrl1 = TextEditingController();
      final ctrl2 = TextEditingController();
      final node1 = FocusNode();
      final node2 = FocusNode();
      String submitted = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                TvTextField(
                  controller: ctrl1,
                  focusNode: node1,
                  labelText: 'Search',
                  hintText: 'Type movie title...',
                  onSubmitted: (v) => submitted = v,
                ),
                const SizedBox(height: 16),
                TvTextField(
                  controller: ctrl2,
                  focusNode: node2,
                  labelText: 'Server URL',
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ),
      );

      // Focus first field & verify editing guard is active (blocks global shortcut hijacking)
      node1.requestFocus();
      await tester.pumpAndSettle();
      expect(node1.hasFocus, isTrue);
      expect(TvTextField.isAnyEditing, isTrue);

      // Type text including spaces and 'f' (formerly hijacked by global shortcuts)
      await tester.enterText(find.byType(TextField).first, 'fast furious');
      await tester.pumpAndSettle();
      expect(ctrl1.text, 'fast furious');

      // D-pad DOWN escapes single-line field cleanly to the next field
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(node2.hasFocus, isTrue);

      // D-pad UP returns cleanly to the first field, then submit via search action
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(node1.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(submitted, 'fast furious');

      // Remote Keyboard fallback icon is rendered in TV mode
      expect(find.byIcon(Icons.keyboard_rounded), findsNWidgets(2));

      ctrl1.dispose();
      ctrl2.dispose();
      node1.dispose();
      node2.dispose();
    });

    testWidgets('TvOnScreenKeyboard fallback types URL tokens and submits via remote',
        (tester) async {
      DeviceFormFactor.forceTvMode.value = true;
      final urlCtrl = TextEditingController();
      String? submittedUrl;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: TvTextField(
                controller: urlCtrl,
                labelText: 'M3U URL',
                keyboardType: TextInputType.url,
                onSubmitted: (v) => submittedUrl = v,
              ),
            ),
          ),
        ),
      );

      // Open built-in remote keyboard fallback
      await tester.tap(find.byIcon(Icons.keyboard_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TvOnScreenKeyboard), findsOneWidget);

      // Tap URL quick token + characters + DONE
      await tester.tap(find.text('http://'));
      await tester.pump();
      await tester.tap(find.text('t'));
      await tester.pump();
      await tester.tap(find.text('v'));
      await tester.pump();
      await tester.tap(find.text('.m3u'));
      await tester.pump();
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      expect(urlCtrl.text, 'http://tv.m3u');
      expect(submittedUrl, 'http://tv.m3u');
      expect(find.byType(TvOnScreenKeyboard), findsNothing);

      urlCtrl.dispose();
    });
  });

  group('Priority 2 & 3 — Remote Navigation, Focus Restoration & Tamba Blue Focus', () {
    testWidgets('TvFocusable distinguishes Focused (Blue) vs Selected (Red) vs Active and activates on SELECT',
        (tester) async {
      var pressed = 0;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                TvFocusable(
                  focusNode: focusNode,
                  onPressed: () => pressed++,
                  child: const Text('Focusable Item'),
                ),
                const TvFocusable(
                  isSelected: true,
                  child: Text('Selected Item'),
                ),
                const TvFocusable(
                  isActive: true,
                  child: Text('Active Item'),
                ),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Verify Focused state uses Tamba Blue border & fill
      final focusedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(TvFocusable).first,
          matching: find.byType(AnimatedContainer),
        ),
      );
      final focusedDec = focusedContainer.decoration! as BoxDecoration;
      expect(focusedDec.color, AppColors.tvFocusFill);
      expect((focusedDec.border! as Border).top.color, AppColors.tvFocusBright);

      // Verify Selected state uses Tamba Red border (distinct from Focused)
      final selectedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(TvFocusable).at(1),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final selectedDec = selectedContainer.decoration! as BoxDecoration;
      expect((selectedDec.border! as Border).top.color, AppColors.primary);

      // Verify D-pad OK / SELECT activates the focused item
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(pressed, 1);

      focusNode.dispose();
    });

    testWidgets('TvFocusRestorer restores focus after dialog closes', (tester) async {
      final triggerNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TvFocusable(
                  focusNode: triggerNode,
                  autofocus: true,
                  onPressed: () {
                    TvFocusRestorer.runWithFocusRestore(() {
                      return showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Test Dialog'),
                          actions: [
                            TextButton(
                              autofocus: true,
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(triggerNode.hasFocus, isTrue);

      // Open dialog via D-pad SELECT
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Test Dialog'), findsOneWidget);

      // Close dialog and verify focus is restored to the original trigger
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Test Dialog'), findsNothing);
      expect(triggerNode.hasFocus, isTrue);

      triggerNode.dispose();
    });

    testWidgets('PlatformNavigationShell bridges D-pad LEFT from Home content into TV Sidebar',
        (tester) async {
      DeviceFormFactor.forceTvMode.value = true;
      final contentNode = FocusNode(debugLabel: 'FirstPoster');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: PlatformNavigationShell(
              currentRoute: '/home',
              child: Center(
                child: TvFocusable(
                  focusNode: contentNode,
                  onPressed: () {},
                  child: const Text('Home Poster 1'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start focused inside Home content
      contentNode.requestFocus();
      await tester.pumpAndSettle();
      expect(contentNode.hasFocus, isTrue);

      // Press D-pad LEFT at left edge of Home content -> MUST jump into Sidebar!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(contentNode.hasFocus, isFalse);

      // Press D-pad RIGHT from Sidebar -> MUST return into Home content!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(contentNode.hasFocus, isTrue);

      contentNode.dispose();
    });
  });
}
